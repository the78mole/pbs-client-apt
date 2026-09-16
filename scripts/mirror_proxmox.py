#!/usr/bin/env python3
"""Spiegelt die Original-Clientpakete aus Proxmox' pbs-client-Repository.

Alles wird gegen die mitgelieferten Proxmox-Schlüssel (keys/) geprüft:
InRelease-Signatur -> SHA256 der Packages-Datei -> SHA256 jedes .deb.

Die Dateien werden umbenannt (``<paket>_<version>+debian<N>_<arch>.deb``), damit
debian-collection-repo sie der richtigen Distribution zuordnet. Der Paketinhalt
bleibt unverändert.

Nutzung:
  mirror_proxmox.py plan              # JSON der Auswahl auf stdout, lädt keine .debs
  mirror_proxmox.py download OUTDIR   # lädt, prüft und benennt um
"""

import gzip
import hashlib
import json
import subprocess
import sys
import tempfile
import urllib.request
from pathlib import Path

BASE = "http://download.proxmox.com/debian/pbs-client"
KEYS = Path(__file__).resolve().parent.parent / "keys"
PACKAGES = ["proxmox-backup-client", "proxmox-backup-client-static"]

SUITE_KEYS = {
    "trixie": KEYS / "proxmox-archive-keyring-trixie.gpg",
    "bookworm": KEYS / "proxmox-release-bookworm.gpg",
}

# (Ziel-Distribution, Debian-Version, Quell-Suite, Quell-Komponente, Architektur, Pakete)
SELECTIONS = [
    ("trixie", "13", "trixie", "main", "amd64", PACKAGES),
    # arm64 gibt es bei Proxmox bisher nur in "test"
    ("trixie", "13", "trixie", "test", "arm64", PACKAGES),
    ("bookworm", "12", "bookworm", "main", "amd64", PACKAGES),
    # Für bookworm/arm64 (z. B. Raspberry Pi OS 12) gibt es nichts: das statisch
    # gelinkte trixie-Paket hängt nur von qrencode ab und läuft dort.
    ("bookworm", "12", "trixie", "test", "arm64", ["proxmox-backup-client-static"]),
]


def fetch(url: str) -> bytes:
    with urllib.request.urlopen(url, timeout=120) as resp:
        return resp.read()


def verified_release(suite: str) -> str:
    """Lädt InRelease und gibt den signierten Klartext zurück."""
    data = fetch(f"{BASE}/dists/{suite}/InRelease")
    with tempfile.TemporaryDirectory() as tmp:
        signed = Path(tmp) / "InRelease"
        signed.write_bytes(data)
        plain = Path(tmp) / "Release"
        subprocess.run(
            ["gpgv", "--keyring", str(SUITE_KEYS[suite]), "--output", str(plain), str(signed)],
            check=True,
            capture_output=True,
        )
        return plain.read_text()


def release_sha256(release: str) -> dict[str, str]:
    hashes, in_sha = {}, False
    for line in release.splitlines():
        if not line.startswith(" "):
            in_sha = line.strip() == "SHA256:"
            continue
        if in_sha:
            digest, _size, name = line.split()
            hashes[name] = digest
    return hashes


def parse_packages(text: str) -> list[dict[str, str]]:
    stanzas = []
    for block in text.strip().split("\n\n"):
        fields, key = {}, None
        for line in block.splitlines():
            if line.startswith((" ", "\t")) and key:
                fields[key] += "\n" + line
            else:
                key, _, value = line.partition(":")
                fields[key] = value.strip()
        stanzas.append(fields)
    return stanzas


def version_gt(a: str, b: str) -> bool:
    return subprocess.run(["dpkg", "--compare-versions", a, "gt", b]).returncode == 0


def plan() -> list[dict[str, str]]:
    releases: dict[str, dict[str, str]] = {}
    result = []
    for target, debver, suite, component, arch, packages in SELECTIONS:
        if suite not in releases:
            releases[suite] = release_sha256(verified_release(suite))
        index = f"{component}/binary-{arch}/Packages.gz"
        raw = fetch(f"{BASE}/dists/{suite}/{index}")
        if hashlib.sha256(raw).hexdigest() != releases[suite].get(index):
            raise SystemExit(f"SHA256 von {suite}/{index} passt nicht zu InRelease")
        latest: dict[str, dict[str, str]] = {}
        for pkg in parse_packages(gzip.decompress(raw).decode()):
            name = pkg.get("Package")
            if name in packages and (name not in latest or version_gt(pkg["Version"], latest[name]["Version"])):
                latest[name] = pkg
        for name in packages:
            if name not in latest:
                raise SystemExit(f"{name} fehlt in {suite}/{component}/{arch}")
            pkg = latest[name]
            result.append(
                {
                    "target": target,
                    "source": f"{suite}/{component}",
                    "package": name,
                    "version": pkg["Version"],
                    "arch": arch,
                    "url": f"{BASE}/{pkg['Filename']}",
                    "sha256": pkg["SHA256"],
                    "filename": f"{name}_{pkg['Version']}+debian{debver}_{arch}.deb",
                }
            )
    return result


def download(outdir: Path) -> None:
    outdir.mkdir(parents=True, exist_ok=True)
    for item in plan():
        data = fetch(item["url"])
        if hashlib.sha256(data).hexdigest() != item["sha256"]:
            raise SystemExit(f"SHA256 von {item['url']} stimmt nicht")
        (outdir / item["filename"]).write_bytes(data)
        print(f"{item['filename']}  <- {item['source']}", file=sys.stderr)


if __name__ == "__main__":
    if len(sys.argv) == 2 and sys.argv[1] == "plan":
        json.dump(plan(), sys.stdout, indent=2)
        print()
    elif len(sys.argv) == 3 and sys.argv[1] == "download":
        download(Path(sys.argv[2]))
    else:
        raise SystemExit(__doc__)
