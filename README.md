# pbs-client-apt

[![Build & Release](https://github.com/the78mole/pbs-client-apt/actions/workflows/release.yml/badge.svg)](https://github.com/the78mole/pbs-client-apt/actions/workflows/release.yml)
[![License: AGPL-3.0](https://img.shields.io/badge/license-AGPL--3.0-blue)](LICENSE)
[![Renovate](https://img.shields.io/badge/renovate-enabled-brightgreen.svg)](https://renovatebot.com)

Inoffizielle Pakete des **Proxmox Backup Client** (`proxmox-backup-client`, `pxar`) für
Ubuntu, dazu gespiegelte Originalpakete von Proxmox für Debian und Raspberry Pi OS.
Du trägst nur ein APT-Repository ein:
[debian-collection-repo](https://the78mole.github.io/debian-collection-repo/).

> Nicht von Proxmox unterstützt. „Proxmox“ ist eine eingetragene Marke der Proxmox
> Server Solutions GmbH.

## Was es gibt

| System | Suite | amd64 | arm64 | Herkunft |
|---|---|---|---|---|
| Ubuntu 22.04 / Mint 21 | `jammy` | ✅ | ✅ | eigener Build |
| Ubuntu 24.04 / Mint 22 | `noble` | ✅ | ✅ | eigener Build |
| Ubuntu 26.04 | `resolute` | ✅ | ✅ | eigener Build |
| Debian 13 / Raspberry Pi OS (trixie) | `trixie` | ✅ Proxmox `main` | ✅ Proxmox **`test`** | Original, gespiegelt |
| Debian 12 / Raspberry Pi OS (bookworm) | `bookworm` | ✅ Proxmox `main` (3.4.x) | ⚠️ nur `-static` aus trixie `test` | Original, gespiegelt |

32-Bit (armhf) gibt es nicht. Proxmox baut dafür nichts, und der Code unterstützt die
Architektur nicht.

## Installation

```bash
curl -fsSL https://the78mole.github.io/debian-collection-repo/public.key \
  | sudo gpg --dearmor -o /usr/share/keyrings/debian-collection-repo.gpg
. /etc/os-release
echo "deb [signed-by=/usr/share/keyrings/debian-collection-repo.gpg] https://the78mole.github.io/debian-collection-repo ${UBUNTU_CODENAME:-$VERSION_CODENAME} main" \
  | sudo tee /etc/apt/sources.list.d/debian-collection-repo.list
sudo apt update
sudo apt install proxmox-backup-client     # oder: proxmox-backup-client-static (nur Debian)
```

`${UBUNTU_CODENAME:-$VERSION_CODENAME}` sorgt dafür, dass Linux Mint die passende
Ubuntu-Suite bekommt.

## Wie es funktioniert

```
Proxmox git ──► GitHub Actions (täglich) ──► GitHub-Release ──► debian-collection-repo ──► GitHub Pages
Proxmox APT ─┘   Ubuntu-Builds + Spiegel      (.debs, Manifest)    (sortiert nach Suite, signiert)
```

1. **Planen** (`plan`):
   - `scripts/resolve-sources.sh` wählt den letzten Release-Stand von `proxmox-backup`, also den letzten „bump version“-Commit. Die Abhängigkeits-Repos setzt es auf den Stand zu diesem Zeitpunkt.
   - `scripts/mirror_proxmox.py plan` ermittelt die neuesten Proxmox-Pakete.
   - `scripts/make-manifest.sh` fasst beides samt Hash der Build-Skripte zusammen.

   Ein Release entsteht nur, wenn sich dieser Hash gegenüber dem letzten Release ändert oder der Lauf manuell mit `force` gestartet wird.
2. **Bauen** (`build`): Pro Ubuntu-Version und Architektur baut `docker/Dockerfile` im
   passenden `ubuntu:<version>`-Image (arm64 auf nativen arm64-Runnern) und paketiert mit
   `scripts/package-deb.sh`. Danach wird das Paket in einem frischen Container per apt
   installiert und getestet.
3. **Spiegeln** (`mirror`): `scripts/mirror_proxmox.py download` lädt die Originalpakete.
   Die Signatur der `InRelease`-Datei wird gegen die Proxmox-Schlüssel in `keys/` geprüft,
   danach die SHA256-Summen von Index und Paket. Die Dateien bekommen `+debian12` bzw.
   `+debian13` in den Namen, damit das Collection-Repo sie zuordnen kann. Der Inhalt
   bleibt unverändert.
4. **Veröffentlichen** (`release`): Tag `v<upstream-version>-r<n>` mit allen .debs,
   `manifest.json` und dem `Cargo.lock` jedes Builds.

**Versionen der eigenen Builds:** `4.2.6-1+ubuntu24.04.r1`. `r<n>` steigt, wenn dieselbe
Upstream-Version neu gebaut wird (z. B. nach Änderungen an den Skripten), damit apt
aktualisiert. Durch das `+` sind die Pakete höher als ein gleichnamiges Proxmox-Original.

Warum für Ubuntu überhaupt Anpassungen nötig sind (Crates nicht auf crates.io,
`.cargo/config.toml`, `pkgconf`, libfuse 3.10 auf 22.04), steht in
`scripts/build-client.sh` und in den Anleitungen unter [docs/](docs/).

## Selbst bauen

Siehe [docs/ubuntu-22.04.md](docs/ubuntu-22.04.md), [docs/ubuntu-24.04.md](docs/ubuntu-24.04.md)
und [docs/ubuntu-26.04.md](docs/ubuntu-26.04.md). Kurzfassung mit Docker:

```bash
docker build -f docker/Dockerfile --build-arg UBUNTU_VERSION=24.04 -t pbs-client-build:24.04 .
cid=$(docker create pbs-client-build:24.04) && docker cp "$cid:/out" ./out && docker rm "$cid"
```

## Lizenz

AGPL-3.0, wie der Proxmox-Code, den dieses Repo baut und anpasst. Die Release-Notes
verlinken für jeden Build die exakten Upstream-Commits.
