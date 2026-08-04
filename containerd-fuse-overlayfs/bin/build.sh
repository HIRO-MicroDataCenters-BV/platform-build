#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
ETC_DIR="${ROOT_DIR}/etc"
TARGET_DIR="${ROOT_DIR}/target"
VERSION_PATH="${TARGET_DIR}/VERSION"
RELEASE_DIR="${TARGET_DIR}/release"
PACKAGE_STEM=containerd-fuse-overlayfs

usage() {
    echo "Usage: $0 {determine_version, build <arch: arm64, amd64>, package <platform: amd64|arm64> <os: ubuntu-26.04>}"
    exit 1
}

main() {
    if [ $# -lt 1 ]; then
        usage
    fi
    case "$1" in
        determine_version)
            determine_version
            ;;
        build)
            if [ $# -ne 2 ]; then
                usage
            fi
            build $2
            ;;
        package)
            if [ $# -ne 3 ]; then
                usage
            fi
            package $2 $3
            ;;
        *)
            echo "Error: Invalid command '$1'"
            usage
            ;;
    esac
}

build() {
    echo "Building binary..."
    ARCH="${1?Architecture not specified, e.g. arm64, arm64}"

    mkdir -p ${TARGET_DIR}
    cd ${TARGET_DIR}

    VERSION=$(cat ${VERSION_PATH})
    CFO_TAG="v${VERSION}"


    wget -P /tmp/ https://github.com/containerd/fuse-overlayfs-snapshotter/releases/download/${CFO_TAG}/containerd-fuse-overlayfs-${VERSION}-linux-${ARCH}.tar.gz
    tar -C ${TARGET_DIR} -xzf /tmp/containerd-fuse-overlayfs-${VERSION}-linux-${ARCH}.tar.gz

    echo "Binary is ready."
}

determine_version() {
    mkdir -p ${TARGET_DIR}
    cd ${TARGET_DIR}

    TAG="${GITHUB_REF_NAME:-$(git describe --tags --exact-match 2>/dev/null)}" || {
        echo "Error: Current commit (HEAD) does not have a Git tag." >&2
        exit 1
    }

    local VERSION
    VERSION=$(echo "$TAG" | sed -E 's/^[^0-9]*//')

    if [[ -z "$VERSION" ]]; then
        echo "Error: Tag '$TAG' does not contain a valid version format." >&2
        return 1
    fi
    echo "Version ${VERSION}"
    echo -n "${VERSION}" > "${VERSION_PATH}"
}

package() {
    echo "Packaging ..."
    PLATFORM="${1?Platform not specified, e.g. arm64|amd64}"
    OS_VERSION="${2?OS not specified, e.g. ubuntu-22.10|ubuntu-26.04}"

    cd "${TARGET_DIR}"

    VERSION=$(cat ${VERSION_PATH})

    PACKAGE_NAME="${PACKAGE_STEM}-v${VERSION}_${PLATFORM}-${OS_VERSION}"
    ROOT_PKG_DIR="${TARGET_DIR}/${PACKAGE_NAME}"

    PACKAGE_BIN_DIR="${ROOT_PKG_DIR}/usr/local/bin/"
    SYSTEMD_SVC="${ROOT_PKG_DIR}/etc/systemd/system"

    rm -rf "${ROOT_PKG_DIR}"

    # Package artifacts
    mkdir -p "${ROOT_PKG_DIR}/DEBIAN"
    cp ${ROOT_DIR}/debian/* "${ROOT_PKG_DIR}/DEBIAN"
    sed -i "s/0.0.0/${VERSION}/" "${ROOT_PKG_DIR}/DEBIAN/control"
    sed -i "s/amd64/${PLATFORM}/" "${ROOT_PKG_DIR}/DEBIAN/control"
    chmod 755 "${ROOT_PKG_DIR}/DEBIAN/postinst" \
              "${ROOT_PKG_DIR}/DEBIAN/postrm" 2>/dev/null || true

    # Binary
    mkdir -p ${PACKAGE_BIN_DIR}
    cp "${TARGET_DIR}/containerd-fuse-overlayfs-grpc" "${PACKAGE_BIN_DIR}/"
    chmod 755 "${PACKAGE_BIN_DIR}/containerd-fuse-overlayfs-grpc"

    # systemd service
    mkdir -p ${SYSTEMD_SVC}
    cp "${ETC_DIR}/containerd-fuse-overlayfs.service" "${SYSTEMD_SVC}/"
    chmod 644 "${SYSTEMD_SVC}/containerd-fuse-overlayfs.service"

    # Building package
    dpkg-deb --build --root-owner-group "${PACKAGE_NAME}"

    echo "Package is ready."
}

main "$@"
