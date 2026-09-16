# Hintergründe zum Ubuntu-Build

## Warum nicht einfach `cargo build`?

1. **`.cargo/config.toml`** im Repo `proxmox-backup` leitet crates.io auf
   `/usr/share/cargo/registry` um, also auf die als Debian-Pakete (`librust-*-dev`)
   installierten Crates. Die gibt es auf Ubuntu nicht. `build-client.sh` löscht die Datei
   im Build-Klon.
2. **Die Proxmox-Crates sind nicht auf crates.io** (`proxmox-*`, `pbs-api-types`,
   `pxar`, `pathpatterns` in Version 1, `proxmox-fuse`). Sie werden aus diesen Repos
   geklont und per `[patch.crates-io]` eingebunden. Die Patch-Tabelle erzeugt das Skript
   als `cargo-patch.toml` und übergibt sie mit `cargo --config`. `Cargo.toml` bleibt
   dabei unverändert.
   - `https://git.proxmox.com/git/proxmox.git` (Monorepo, inkl. `pbs-api-types`)
   - `https://git.proxmox.com/git/pxar.git`
   - `https://git.proxmox.com/git/pathpatterns.git`
   - `https://git.proxmox.com/git/proxmox-fuse.git`
3. **`proxmox-fuse`** ruft im Build-Skript `pkgconf` auf (nicht `pkg-config`).
   Deshalb wird das Paket `pkgconf` installiert.
4. **Nur Ubuntu 22.04:** libfuse 3.10 kennt `fuse_file_info.noflush` noch nicht (das
   gibt es ab 3.11). Das Skript setzt in `proxmox-fuse/src/glue.c` einen `#if`-Guard,
   der dort No-Op-Zugriffsfunktionen einsetzt. Auf neueren Systemen ändert der Guard
   nichts. `proxmox-backup-client` selbst nutzt `noflush` nicht.
5. **Rust über rustup:** Die Ubuntu-Pakete `rustc`/`cargo` sind auf 22.04 und 24.04 zu
   alt.

## Welcher Stand wird gebaut?

`scripts/resolve-sources.sh` wählt standardmäßig den **letzten Release-Stand**:

- **`proxmox-backup`:** den letzten Commit auf `master`, der `debian/changelog` ändert (Proxmox' „bump version to X“). Die Git-Tags von Proxmox hinken oft hinterher.
- **Abhängigkeiten** (`proxmox`, `pxar`, `pathpatterns`, `proxmox-fuse`): den letzten `master`-Commit vor diesem Zeitpunkt.

Einzelne Stände lassen sich per Umgebungsvariable festlegen: `PBS_COMMIT`,
`PROXMOX_COMMIT`, `PXAR_COMMIT`, `PATHPATTERNS_COMMIT`, `PROXMOX_FUSE_COMMIT`. Erlaubt
sind Commit-Hashes oder Referenzen wie `origin/master`.

Das Repo hat kein `Cargo.lock` (Debian baut gegen die Paketversionen). Fremd-Crates holt
Cargo daher in der jeweils neuesten semver-kompatiblen Version. Das `Cargo.lock` jedes
CI-Builds liegt deshalb im Release und im Paket unter
`/usr/share/doc/proxmox-backup-client/`.
