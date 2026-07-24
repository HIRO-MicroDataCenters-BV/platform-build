#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
ETC_DIR="${ROOT_DIR}/etc"
TARGET_DIR="${ROOT_DIR}/target"
VERSION_PATH="${TARGET_DIR}/VERSION"
RELEASE_DIR="${TARGET_DIR}/release"
PACKAGE_STEM=ipxe-boot

usage() {
    echo "Usage: $0 {install_dependencies, determine_version, build <arch: arm64, x86_64>, package <arch: arm64|x86_64> <platform: amd64|arm64> <os: ubuntu-26.04>}"
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
        install_dependencies)
            install_dependencies
            ;;
        build)
            if [ $# -ne 2 ]; then
                usage
            fi
            build $2
            ;;
        package)
            if [ $# -ne 4 ]; then
                usage
            fi
            package $2 $3 $4
            ;;
        *)
            echo "Error: Invalid command '$1'"
            usage
            ;;
    esac
}

install_dependencies() {
    echo "Install dependencies ..."
    apt install -y \
        git \
        gcc \
        make \
        liblzma-dev \
        build-essential \
        devscripts \
        debhelper 
    echo "Dependencies installed."
}

build() {
    echo "Building binary..."
    ARCH="${1?Architecture not specified, e.g. arm64, x86_64}"

    mkdir -p ${TARGET_DIR}
    cd ${TARGET_DIR}
    git clone https://github.com/ipxe/ipxe.git
    cd ${TARGET_DIR}/ipxe/src
    make bin-${ARCH}-efi/ipxe.efi EMBED=${ETC_DIR}/boot.ipxe
    make bin-${ARCH}-efi/snponly.efi EMBED=${ETC_DIR}/boot.ipxe    

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
    ARCH="${1?Architecture not specified, e.g. arm64|x86_64}"
    PLATFORM="${2?Platform not specified, e.g. arm64|amd64}"
    OS_VERSION="${3?OS not specified, e.g. ubuntu-22.10|ubuntu-26.04}"

    cd "${TARGET_DIR}"

    VERSION=$(cat ${VERSION_PATH})
    PACKAGE_NAME="${PACKAGE_STEM}-${VERSION}_${PLATFORM}-${OS_VERSION}"
    PACKAGE_BINARY="${TARGET_DIR}/${PACKAGE_NAME}/usr/lib/${PACKAGE_STEM}/"

    mkdir -p "${TARGET_DIR}/${PACKAGE_NAME}/DEBIAN"
    cp ${ROOT_DIR}/debian/* "${TARGET_DIR}/${PACKAGE_NAME}/DEBIAN"
    sed -i "s/0.0.0/${VERSION}/" "${TARGET_DIR}/${PACKAGE_NAME}/DEBIAN/control"

    mkdir -p ${PACKAGE_BINARY}
    cp "${TARGET_DIR}/ipxe/src/bin-${ARCH}-efi/ipxe.efi" ${PACKAGE_BINARY}
    cp "${TARGET_DIR}/ipxe/src/bin-${ARCH}-efi/snponly.efi" ${PACKAGE_BINARY}
    dpkg-deb --build --root-owner-group "${PACKAGE_NAME}"

    echo "Package is ready."
}

main "$@"
