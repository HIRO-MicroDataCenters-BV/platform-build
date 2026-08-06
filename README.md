# platform-build

Build system for HIRO Micro Data Centers infrastructure components. Builds and packages networking, provisioning, and container runtime tools into Debian packages for Ubuntu 22.04, 24.04, and 26.04 on `amd64` and `arm64` architectures.

## Overview

This repository provides:

- **Builder image** — A multi-platform, multi-OS Docker base image for reproducible builds.
- **ipxe** — Pre-built iPXE boot images (UEFI `.efi` binaries) for network booting.
- **matchbox** — A RESTful API & webhook engine for bare metal provisioning (forked from [poseidon/matchbox](https://github.com/poseidon/matchbox)).
- **frr** — FRRouting (FRR) with extended VRF, VPNv4/6, and SRv6 support.
- **containerd-fuse-overlayfs** — containerd fuse-overlayfs snapshotter with GRPC integration.
- **vemdc** — Virtual Edge Micro Data Center. A complete virtualized network boot infrastructure (DHCP, DNS/radvd, Matchbox, squashfs-based rootfs) for provisioning head and worker nodes.

## Directory structure

```
.
├── builder/                              # Multi-OS builder Docker images
│   ├── ubuntu-22.04.Dockerfile
│   ├── ubuntu-24.04.Dockerfile
│   ├── ubuntu-26.04.Dockerfile
│   ├── VERSION                           # Base version for the build system
│   └── version.sh                        # Version calculation logic (CI)
├── ipxe/                                 # iPXE network boot images
│   ├── bin/build.sh
│   ├── etc/boot.ipxe                     # Embedded iPXE boot script
│   └── debian/                           # Debian package metadata
├── matchbox/                             # Bare-metal provisioning server
│   ├── bin/build.sh
│   └── debian/                           # Debian package metadata
├── frr/                                  # FRRouting packages
│   └── bin/build.sh
├── containerd-fuse-overlayfs/            # containerd snapshotter + GRPC
│   ├── bin/build.sh
│   ├── etc/containerd-fuse-overlayfs.service
│   └── debian/
├── vemdc/                                # Virtual Edge Micro Data Center
│   ├── bin/emdc.sh                       # Main orchestration script
│   ├── bin/head.sh                       # Head node setup script
│   ├── squashfs/                         # Squashfs rootfs builder
│   ├── etc/                              # Configs (DHCP, radvd, cloud-init seed)
│   ├── matchbox/                         # Matchbox data (assets, profiles, groups)
│   └── target/                           # Produced images (seed.iso, etc.)
└── .github/workflows/                    # GitHub Actions CI pipelines
    ├── build-image.yaml                  # Build & publish builder Docker images
    ├── ipxe.yaml                         # Build & release iPXE packages
    ├── matchbox.yaml                     # Build & release Matchbox packages
    ├── frr.yaml                          # Build & release FRR packages
    └── containerd-fuse-overlayfs.yaml    # Build & release CFO packages
```

## Builder image

The builder provides a consistent environment for building all components. It is published to `ghcr.io/hiro-microdatacenters-bv/platform-build`.

```bash
# Build locally
docker build -t platform-build:ubuntu-24.04 -f builder/ubuntu-24.04.Dockerfile .

# Use the published image (runs inside a container with all deps pre-installed)
docker run --rm -it ghcr.io/hiro-microdatacenters-bv/platform-build:ubuntu-24.04-linux-amd64-latest
```

The image supports `linux/amd64` and `linux/arm64` for Ubuntu 22.04, 24.04, and 26.04.

**Publishing:** Triggered automatically every Sunday via cron (on `main`) or manually via `workflow_dispatch`.

## CI/CD — Publishing releases

Each component has its own GitHub Actions workflow. To publish a new release:

1. Run the workflow manually from the Actions tab, or push a version tag.
2. The supported tag prefixes per component:

| Component | Tag prefix | Produces |
|-----------|-----------|----------|
| iPXE | `ipxe_*` | `.deb` packages → GitHub Release |
| Matchbox | `matchbox_*` | `.deb` packages → GitHub Release |
| FRR | `frr_*` | `.deb` packages → GitHub Release |
| containerd-fuse-overlayfs | `cfo_*` | `.deb` packages → GitHub Release |

All builds run inside the published builder image across all OS/arch combinations.

## vemdc — Virtual Edge Micro Data Center

`vemdc` provides a full virtual network boot infrastructure for provisioning virtual EMDC COM nodes.

### Quick start

```bash
# 1. Install build dependencies
vemdc/bin/emdc.sh install_dependencies

# 2. Create a virtual network (libvirt)
vemdc/bin/emdc.sh create_network

# 3. Boot the head node
vemdc/bin/emdc.sh launch_head

# 4. SSH into the head node and complete setup
ssh ubuntu@192.168.22.2

# On the head node:
sudo /mnt/platform-build/bin/head.sh install_dependencies
sudo /mnt/platform-build/bin/head.sh setup
/mnt/platform-build/bin/head.sh configure_kubectl

# 5. Boot worker nodes
vemdc/bin/emdc.sh launch_worker 01
vemdc/bin/emdc.sh launch_worker 02

# 6. Join workers to the cluster (copy the join command from head node)
# ssh ubuntu@<worker-ip>
# sudo <join-command from head node>
```

### Squashfs builder

`vemdc/squashfs/` builds a compressed root filesystem for diskless/booted nodes:

```bash
cd vemdc/squashfs

sudo ./build.sh init      # Initialize debootstrap filesystem
sudo ./build.sh install   # Install additional packages
./build.sh cleanup        # Remove chroot artifacts (optional)
sudo ./build.sh build     # Create the squashfs image
./build.sh upload         # Upload to Matchbox assets (optional)
```

### Architecture

```
vemdc/
├── bin/
│   ├── emdc.sh          # Orchestrate VMs, networks, and provisioning
│   └── head.sh          # Head node setup: DNS, DHCP, Matchbox, k8s
├── etc/
│   ├── seed/            # Cloud-init seed ISO configs (user-data, meta-data, network-config)
│   ├── kea/             # DHCPv4/DHCPv6 configuration
│   ├── radvd/radvd.conf # IPv6 router advertisements
│   ├── matchbox/        # Matchbox systemd service
│   └── emdc-net.xml     # Libvirt network definition
├── matchbox/
│   └── matchbox_data/
│       ├── assets/      # Bootable ISOs, kernel/initrd, snapshotted squashfs, cloud-init files
│       ├── profiles/    # Matchbox profiles (ubuntu-26-live, ubuntu-26-install, IPv4/IPv6 variants)
│       └── groups/      # Device groups (worker-01, worker-02)
├── squashfs/            # Rootfs builder (install path & diskless chroot)
│   ├── install/         # Full install workflow (Ubuntu, containerd, Kubernetes, Hiromdc)
│   └── diskless/        # Diskless boot chroot (CNI plugins, containerd, zram)
└── target/              # Produced artifacts
    ├── seed.iso         # Cloud-init seed ISO for head node
    ├── network-provisioner.img
    └── resolute-server-cloudimg-amd64.img
```

### Key services (head node)

- **DHCP** (Kea) — Assigns IPs to booting nodes
- **DNS/radvd** — IPv6 routing advertisement
- **Matchbox** — Provides bootloader configs based on device profiles
- **Kubernetes** — Head node acts as the control plane
- **containerd-fuse-overlayfs** — Storage driver for containerd

## Versioning

- **Builder image**: Derived from `builder/VERSION` base, with dev/branch/suffix logic in `builder/version.sh`. Release tags get exact version labels; dev builds use `base+devN-branch-shortsha`.
- **Components** (ipxe, matchbox, frr, cfo): Version is extracted from git tags (e.g., `ipxe_1.2.3` → version `1.2.3`). Produces platform-specific `.deb` filenames like `package-v1.2.3_amd64-ubuntu-24.04.deb`.
