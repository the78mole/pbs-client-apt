#!/usr/bin/env bash
# Packt die mit build-client.sh gebauten Binaries als .deb - auf dem Zielsystem
# ausführen (dpkg-shlibdeps ermittelt die Abhängigkeiten gegen dessen Bibliotheken).
#
# Nutzung: package-deb.sh ARBEITSVERZEICHNIS AUSGABEVERZEICHNIS [REVISION]
# Ergebnis: proxmox-backup-client_<upstream>+ubuntu<VERSION>.r<REVISION>_<arch>.deb
set -euo pipefail

WORK="$(realpath "${1:?Arbeitsverzeichnis fehlt}")"
OUT="$(realpath -m "${2:?Ausgabeverzeichnis fehlt}")"
REVISION="${3:-1}"

# shellcheck source=/dev/null
. "$WORK/sources.env"
# shellcheck source=/dev/null
. /etc/os-release

PBS="$WORK/proxmox-backup"
PKG=proxmox-backup-client
ARCH="$(dpkg --print-architecture)"
VERSION="${PBS_VERSION}+${ID}${VERSION_ID}.r${REVISION}"
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

echo ">> Packe $PKG $VERSION ($ARCH)"
install -D -m 0755 "$PBS/target/release/proxmox-backup-client" "$STAGE/usr/bin/proxmox-backup-client"
install -D -m 0755 "$PBS/target/release/pxar" "$STAGE/usr/bin/pxar"
strip --strip-unneeded "$STAGE/usr/bin/proxmox-backup-client" "$STAGE/usr/bin/pxar"

install -D -m 0644 "$PBS/debian/proxmox-backup-client.bc" "$STAGE/usr/share/bash-completion/completions/proxmox-backup-client"
install -D -m 0644 "$PBS/debian/pxar.bc" "$STAGE/usr/share/bash-completion/completions/pxar"
install -D -m 0644 "$PBS/zsh-completions/_proxmox-backup-client" "$STAGE/usr/share/zsh/vendor-completions/_proxmox-backup-client"
install -D -m 0644 "$PBS/zsh-completions/_pxar" "$STAGE/usr/share/zsh/vendor-completions/_pxar"

DOC="$STAGE/usr/share/doc/$PKG"
install -D -m 0644 "$PBS/debian/copyright" "$DOC/copyright"
gzip -9n -c "$PBS/debian/changelog" > "$DOC/changelog.Debian.gz"
cat > "$DOC/README.unofficial" <<EOF
Inoffizieller Build von proxmox-backup-client für ${PRETTY_NAME}.
Gebaut von https://github.com/the78mole/pbs-client-apt - nicht von Proxmox unterstützt.

Quellen (AGPL-3.0):
  proxmox-backup  https://git.proxmox.com/?p=proxmox-backup.git;a=commit;h=${PBS_COMMIT}
  proxmox         https://git.proxmox.com/?p=proxmox.git;a=commit;h=${PROXMOX_COMMIT}
  pxar            https://git.proxmox.com/?p=pxar.git;a=commit;h=${PXAR_COMMIT}
  pathpatterns    https://git.proxmox.com/?p=pathpatterns.git;a=commit;h=${PATHPATTERNS_COMMIT}
  proxmox-fuse    https://git.proxmox.com/?p=proxmox-fuse.git;a=commit;h=${PROXMOX_FUSE_COMMIT}
Build-Anpassungen: siehe scripts/build-client.sh im Repository oben.
EOF
cp "$PBS/Cargo.lock" "$DOC/Cargo.lock"
gzip -9n "$DOC/Cargo.lock"

# Abhängigkeiten der Binaries ermitteln (dpkg-shlibdeps erwartet debian/control).
SHLIBS="$(mktemp -d)"
mkdir -p "$SHLIBS/debian"
printf 'Source: %s\n\nPackage: %s\nArchitecture: any\n' "$PKG" "$PKG" > "$SHLIBS/debian/control"
DEPENDS="$(cd "$SHLIBS" && dpkg-shlibdeps -O "$STAGE/usr/bin/proxmox-backup-client" "$STAGE/usr/bin/pxar" 2>/dev/null \
    | sed -n 's/^shlibs:Depends=//p')"
rm -rf "$SHLIBS"

mkdir -p "$STAGE/DEBIAN"
cat > "$STAGE/DEBIAN/control" <<EOF
Package: $PKG
Source: rust-proxmox-backup
Version: $VERSION
Architecture: $ARCH
Maintainer: Daniel Glaser <me@the78mole.de>
Installed-Size: $(du -sk --exclude=DEBIAN "$STAGE" | cut -f1)
Depends: qrencode, $DEPENDS
Conflicts: proxmox-backup-client-static
Section: admin
Priority: optional
Homepage: https://github.com/the78mole/pbs-client-apt
Description: Proxmox Backup Client tools (unofficial ${ID} ${VERSION_ID} build)
 This package contains the Proxmox Backup client, which provides a
 simple command line tool to create and restore backups.
 .
 Unofficial build from the upstream sources for ${PRETTY_NAME},
 not supported by Proxmox.
EOF

mkdir -p "$OUT"
DEB="$OUT/${PKG}_${VERSION}_${ARCH}.deb"
dpkg-deb --root-owner-group -Zxz --build "$STAGE" "$DEB" >/dev/null
cp "$PBS/Cargo.lock" "$OUT/Cargo.lock.${ID}${VERSION_ID}.${ARCH}"
dpkg-deb --info "$DEB" | sed -n '/Package:/,/Description:/p'
echo ">> $DEB"
