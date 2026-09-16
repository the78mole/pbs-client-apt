#!/usr/bin/env bash
# Baut proxmox-backup-client und pxar aus den Proxmox-Git-Repos mit rustup-Cargo.
#
# Nutzung: build-client.sh [ARBEITSVERZEICHNIS]   (Standard: ./pbs-src)
#
# Welche Commits gebaut werden, legt resolve-sources.sh fest (Standard: letzter
# Release-Stand von proxmox-backup). Einzelne Commits lassen sich per Umgebung
# vorgeben, siehe dort.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK="$(realpath -m "${1:-pbs-src}")"

echo ">> Hole Quellen nach $WORK"
"$SCRIPT_DIR/resolve-sources.sh" "$WORK" > "$WORK.sources.env"
mv "$WORK.sources.env" "$WORK/sources.env"
# shellcheck source=/dev/null
. "$WORK/sources.env"
cat "$WORK/sources.env"

cd "$WORK"
checkout() { git -C "$1" checkout --quiet --force "$2" && git -C "$1" clean --quiet -fdx -e target; }
checkout proxmox-backup "$PBS_COMMIT"
checkout proxmox "$PROXMOX_COMMIT"
checkout pxar "$PXAR_COMMIT"
checkout pathpatterns "$PATHPATTERNS_COMMIT"
checkout proxmox-fuse "$PROXMOX_FUSE_COMMIT"

# libfuse < 3.11 (Ubuntu 22.04) kennt fuse_file_info.noflush nicht:
# Zugriffsfunktionen dort als No-Op bereitstellen. Auf neueren Systemen wirkungslos.
if ! grep -q 'FUSE_MINOR_VERSION' proxmox-fuse/src/glue.c; then
    sed -i 's/^MAKE_ACCESSORS(noflush)$/#if FUSE_MAJOR_VERSION > 3 || (FUSE_MAJOR_VERSION == 3 \&\& FUSE_MINOR_VERSION >= 11)\nMAKE_ACCESSORS(noflush)\n#else\nextern void glue_set_ffi_noflush(struct fuse_file_info *ffi, unsigned int value) { (void)ffi; (void)value; }\nextern unsigned int glue_get_ffi_noflush(struct fuse_file_info *ffi) { (void)ffi; return 0; }\n#endif/' proxmox-fuse/src/glue.c
fi

# Die mitgelieferte .cargo/config.toml leitet crates.io auf die Debian-Pakete
# unter /usr/share/cargo/registry um - die gibt es auf Ubuntu nicht.
rm -f proxmox-backup/.cargo/config.toml

# Proxmox-Crates sind nicht auf crates.io: per [patch] auf die lokalen Klone zeigen.
echo ">> Erzeuge cargo-patch.toml"
{
    echo "[patch.crates-io]"
    for toml in proxmox/*/Cargo.toml pxar/Cargo.toml pathpatterns/Cargo.toml proxmox-fuse/Cargo.toml; do
        name="$(sed -n '/^\[package\]/,/^\[/{s/^name *= *"\(.*\)"/\1/p}' "$toml" | head -1)"
        [ -n "$name" ] && echo "$name = { path = \"$WORK/$(dirname "$toml")\" }"
    done
} > cargo-patch.toml

echo ">> Baue (das dauert beim ersten Mal eine Weile)"
cd proxmox-backup
# REPOID wird sonst per `git rev-parse HEAD` ermittelt - gleiches Ergebnis, aber explizit.
REPOID="$PBS_COMMIT" cargo build --release --config ../cargo-patch.toml \
    --package proxmox-backup-client --bin proxmox-backup-client \
    --package pxar-bin --bin pxar

echo
echo ">> Fertig:"
ls -lh target/release/proxmox-backup-client target/release/pxar
