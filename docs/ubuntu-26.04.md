# proxmox-backup-client auf Ubuntu 26.04 LTS (resolute) bauen

Hintergründe und Details stehen in den [Build-Notizen](build-notes.md).
Fertige Pakete gibt es über das APT-Repo, siehe [README](../README.md).

Getestet: 2026-09-16, Client 4.2.6, Rust 1.98.1, ohne Anpassungen.

## 1. Build-Abhängigkeiten

```bash
sudo apt update
sudo apt install --no-install-recommends \
    build-essential pkgconf git curl ca-certificates \
    libssl-dev libacl1-dev libfuse3-dev libsystemd-dev uuid-dev
```

## 2. Rust über rustup

```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal
. "$HOME/.cargo/env"
rustc --version
```

Das Ubuntu-eigene `rustc` von 26.04 ist neu genug, dass es vermutlich auch reicht.
Getestet wurde aber nur mit rustup stable.

## 3. Bauen

```bash
scripts/build-client.sh ~/build/pbs-src
```

## 4. Installieren und testen

```bash
sudo install -m 0755 ~/build/pbs-src/proxmox-backup/target/release/{proxmox-backup-client,pxar} /usr/local/bin/
proxmox-backup-client version
```

Alternativ ein .deb bauen und installieren (zieht die Laufzeit-Pakete automatisch nach):

```bash
scripts/package-deb.sh ~/build/pbs-src ./out
sudo apt install ./out/proxmox-backup-client_*.deb
```

Laufzeit-Pakete für Rechner, auf denen nur die Binary landen soll. Anders als bei
22.04/24.04 heißt das fuse-Paket hier `libfuse3-4` (soname `libfuse3.so.4`), und
zstd/zlib werden dynamisch gelinkt:

```bash
sudo apt install libfuse3-4 libacl1 libssl3t64 libzstd1 zlib1g
```

Eine auf 26.04 gebaute Binary läuft deshalb **nicht** auf 24.04 oder älter (neueres
glibc, anderes libfuse-soname).
