# Baut und paketiert proxmox-backup-client für eine Ubuntu-Version.
# Aufruf aus dem Repo-Root:
#   docker build -f docker/Dockerfile --build-arg UBUNTU_VERSION=24.04 -t pbs-client-build:24.04 .
# Ergebnis im Image unter /out (.deb + Cargo.lock).
ARG UBUNTU_VERSION=24.04
FROM ubuntu:${UBUNTU_VERSION}

ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential pkgconf git curl ca-certificates \
        libssl-dev libacl1-dev libfuse3-dev libsystemd-dev uuid-dev \
    && rm -rf /var/lib/apt/lists/*

RUN curl -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal --default-toolchain stable
ENV PATH=/root/.cargo/bin:$PATH

# Leer = automatisch auflösen (siehe scripts/resolve-sources.sh)
ARG PBS_COMMIT=
ARG PROXMOX_COMMIT=
ARG PXAR_COMMIT=
ARG PATHPATTERNS_COMMIT=
ARG PROXMOX_FUSE_COMMIT=
ARG REVISION=1
ARG CARGO_BUILD_JOBS

COPY scripts/ /opt/pbs-client-apt/scripts/
RUN PBS_COMMIT=${PBS_COMMIT} PROXMOX_COMMIT=${PROXMOX_COMMIT} PXAR_COMMIT=${PXAR_COMMIT} \
        PATHPATTERNS_COMMIT=${PATHPATTERNS_COMMIT} PROXMOX_FUSE_COMMIT=${PROXMOX_FUSE_COMMIT} \
        /opt/pbs-client-apt/scripts/build-client.sh /src \
    && /opt/pbs-client-apt/scripts/package-deb.sh /src /out ${REVISION} \
    && rm -rf /src/proxmox-backup/target/release/build /src/proxmox-backup/target/release/deps
