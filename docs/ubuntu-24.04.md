# proxmox-backup-client auf Ubuntu 24.04 LTS (noble) bauen

Gilt auch für **Linux Mint 22 / 22.1 / 22.2** (Basis: Ubuntu 24.04 noble).
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

Das Ubuntu-Paket `rustc` (1.75) ist zu alt.

```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal
. "$HOME/.cargo/env"
rustc --version
```

Wenn rustup schon installiert ist, reicht `rustup update stable`.

## 3. Bauen

```bash
cd pbs-client-apt
scripts/build-client.sh ~/build/pbs-src
```

Der erste Build dauert je nach Rechner 2–5 Minuten, der Download läuft komplett über
`git.proxmox.com` und crates.io.

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

Laufzeit-Pakete für Rechner, auf denen nur die Binary landen soll:

```bash
sudo apt install libfuse3-3 libacl1 libssl3t64
```

## 5. Erstes Backup (Beispiel)

```bash
export PBS_REPOSITORY='backup@pbs@pbs.example.com:datastore1'
export PBS_PASSWORD='...'          # oder API-Token: user@pbs!token@host:store + Secret
export PBS_FINGERPRINT='aa:bb:...' # bei selbstsigniertem Zertifikat

proxmox-backup-client backup home.pxar:/home/daniel
proxmox-backup-client snapshot list
```

## Aktualisieren

`scripts/build-client.sh ~/build/pbs-src` einfach erneut ausführen und dann Schritt 4
wiederholen.
