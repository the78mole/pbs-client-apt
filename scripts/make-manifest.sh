#!/usr/bin/env bash
# Erzeugt manifest.json: beschreibt vollständig, was ein Release enthält.
# Ändert sich der "key", ist ein neues Release fällig.
#
# Nutzung (aus dem Repo-Root): make-manifest.sh SOURCES_ENV MIRROR_PLAN_JSON > manifest.json
set -euo pipefail

SOURCES_ENV="${1:?sources.env fehlt}"
MIRROR_PLAN="${2:?Mirror-Plan fehlt}"

# shellcheck source=/dev/null
. "$SOURCES_ENV"

# Alles, was den Inhalt der selbst gebauten Pakete oder der Spiegelung beeinflusst.
TOOLING="$(git ls-files scripts docker keys .github/workflows/release.yml | LC_ALL=C sort | xargs sha256sum | sha256sum | cut -d' ' -f1)"

BODY="$(jq -n -S -c \
    --arg pbs_version "$PBS_VERSION" --arg pbs_commit "$PBS_COMMIT" --arg pbs_date "$PBS_DATE" \
    --arg proxmox "$PROXMOX_COMMIT" --arg pxar "$PXAR_COMMIT" --arg pathpatterns "$PATHPATTERNS_COMMIT" \
    --arg proxmox_fuse "$PROXMOX_FUSE_COMMIT" --arg tooling "$TOOLING" --slurpfile mirror "$MIRROR_PLAN" \
    '{
        build: {
            version: $pbs_version, date: $pbs_date,
            commits: {
                "proxmox-backup": $pbs_commit, proxmox: $proxmox, pxar: $pxar,
                pathpatterns: $pathpatterns, "proxmox-fuse": $proxmox_fuse
            }
        },
        tooling: $tooling,
        mirror: ($mirror[0] | map({target, source, package, version, arch, sha256, filename}))
    }')"
KEY="$(printf '%s' "$BODY" | sha256sum | cut -d' ' -f1)"
printf '%s' "$BODY" | jq --arg key "$KEY" '. + {key: $key}'
