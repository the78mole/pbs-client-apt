#!/usr/bin/env bash
# Klont/aktualisiert die Proxmox-Quellrepos und legt fest, welche Commits gebaut werden.
#
# Nutzung: resolve-sources.sh ARBEITSVERZEICHNIS
# Ausgabe (stdout): KEY=VALUE-Zeilen, geeignet für `source` bzw. $GITHUB_OUTPUT
#
# Ohne Vorgaben wird der letzte Release-Stand von proxmox-backup gewählt (der letzte
# Commit, der debian/changelog ändert = "bump version to X"). Die Abhängigkeits-Repos
# werden auf den letzten master-Commit vor diesem Zeitpunkt gesetzt.
# Vorgaben per Umgebung: PBS_COMMIT, PROXMOX_COMMIT, PXAR_COMMIT, PATHPATTERNS_COMMIT,
# PROXMOX_FUSE_COMMIT (jeweils Commit-Hash oder Branch).
set -euo pipefail

WORK="$(realpath -m "${1:?Arbeitsverzeichnis fehlt}")"
GIT_BASE="https://git.proxmox.com/git"
mkdir -p "$WORK"

fetch_repo() {
    local repo="$1"
    if [ -d "$WORK/$repo/.git" ]; then
        git -C "$WORK/$repo" fetch --quiet origin
    else
        git clone --quiet --no-checkout "$GIT_BASE/$repo.git" "$WORK/$repo"
    fi
}

for repo in proxmox-backup proxmox pxar pathpatterns proxmox-fuse; do
    fetch_repo "$repo" >&2
done

pbs="$WORK/proxmox-backup"
PBS_COMMIT="$(git -C "$pbs" rev-parse "${PBS_COMMIT:-$(git -C "$pbs" log -1 --format=%H origin/master -- debian/changelog)}")"
PBS_DATE="$(git -C "$pbs" show -s --format=%cI "$PBS_COMMIT")"
PBS_VERSION="$(git -C "$pbs" show "$PBS_COMMIT:debian/changelog" | sed -n '1s/^[^(]*(\([^)]*\)).*/\1/p')"

dep_commit() {
    local repo="$1" given="$2"
    if [ -n "$given" ]; then
        git -C "$WORK/$repo" rev-parse "$given"
    else
        git -C "$WORK/$repo" rev-list -1 --before="$PBS_DATE" origin/master
    fi
}

echo "PBS_COMMIT=$PBS_COMMIT"
echo "PBS_VERSION=$PBS_VERSION"
echo "PBS_DATE=$PBS_DATE"
echo "PROXMOX_COMMIT=$(dep_commit proxmox "${PROXMOX_COMMIT:-}")"
echo "PXAR_COMMIT=$(dep_commit pxar "${PXAR_COMMIT:-}")"
echo "PATHPATTERNS_COMMIT=$(dep_commit pathpatterns "${PATHPATTERNS_COMMIT:-}")"
echo "PROXMOX_FUSE_COMMIT=$(dep_commit proxmox-fuse "${PROXMOX_FUSE_COMMIT:-}")"
