# proxmox-backup-client auf Ubuntu 22.04 LTS (jammy) bauen

Gilt auch für **Linux Mint 21.x** (Basis: Ubuntu 22.04 jammy).
Hintergründe und Details stehen in den [Build-Notizen](build-notes.md).
Fertige Pakete gibt es über das APT-Repo, siehe [README](../README.md).

Getestet: 2026-09-16, Client 4.2.6, Rust 1.98.1.

> **Besonderheit 22.04:** libfuse3 ist hier Version 3.10 und kennt `noflush` noch
> nicht. `build-client.sh` patcht `proxmox-fuse/src/glue.c` automatisch. Wer von Hand
> baut, muss den Patch selbst anwenden (siehe [Hintergründe](build-notes.md), Punkt 4).

## 1. Build-Abhängigkeiten

```bash
sudo apt update
sudo apt install --no-install-recommends \
    build-essential pkgconf git curl ca-certificates \
    libssl-dev libacl1-dev libfuse3-dev libsystemd-dev uuid-dev
```

Wichtig ist hier `pkgconf`, nicht `pkg-config`: Auf 22.04 sind das zwei getrennte
Pakete, und nur `pkgconf` liefert das Binary `pkgconf`, das `proxmox-fuse` aufruft.
Falls apt einen Konflikt mit einem schon installierten `pkg-config` meldet, das
Ersetzen bestätigen: `pkgconf` stellt auch den Befehl `pkg-config` bereit.

## 2. Rust über rustup

Das Ubuntu-Paket `rustc` ist zu alt.

```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal
. "$HOME/.cargo/env"
rustc --version
```

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

Laufzeit-Pakete für Rechner, auf denen nur die Binary landen soll:

```bash
sudo apt install libfuse3-3 libacl1 libssl3
```

## Einschränkung

Wegen des fuse-Patches ist das Flag `noflush` in der FUSE-Schicht ein No-Op.
`proxmox-backup-client mount` bzw. `map` funktionieren trotzdem, weil das Flag im
Client nicht verwendet wird. Getestet wurden hier aber nur Build, Schlüssel-Erzeugung
und `pxar`, nicht `mount`.
