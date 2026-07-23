#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
ETC_DIR="${ROOT_DIR}/etc"
TARGET_DIR="${ROOT_DIR}/target"
VERSION_PATH="${TARGET_DIR}/VERSION"
RELEASE_DIR="${TARGET_DIR}/release"

usage() {
    echo "Usage: $0 {install_dependencies,determine_version,build,package}"
    exit 1
}

main() {
    if [ $# -ne 1 ]; then
        usage
    fi
    case "$1" in
        install_dependencies)
            install_dependencies
            ;;
        build)
            build
            ;;
        package)
            package
            ;;
        determine_version)
            determine_version
            ;;
        *)
            echo "Error: Invalid command '$1'"
            usage
            ;;
    esac
}

install_dependencies() {
    apt install -y \
        git \
        gcc \
        make \
        liblzma-dev \
        build-essential \
        devscripts \
        debhelper 
}

build() {
    mkdir -p ${TARGET_DIR}
    cd ${TARGET_DIR}
    git clone https://github.com/ipxe/ipxe.git
    cd ${TARGET_DIR}/ipxe/src
    make bin-x86_64-efi/ipxe.efi EMBED=${ETC_DIR}/boot.ipxe
    make bin-x86_64-efi/snponly.efi EMBED=${ETC_DIR}/boot.ipxe    
}

determine_version() {

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
    VERSION=$(cat ${VERSION_PATH})
    PACKAGE_STEM=emdc-ipxe-boot
    PACKAGE_NAME="${PACKAGE_STEM}-${VERSION}_amd64"
    PACKAGE_BINARY="${TARGET_DIR}/${PACKAGE_NAME}/usr/lib/${PACKAGE_STEM}/"

    cd "${TARGET_DIR}"
    mkdir -p "${TARGET_DIR}/${PACKAGE_NAME}/DEBIAN"
    cp ${ROOT_DIR}/debian/* "${TARGET_DIR}/${PACKAGE_NAME}/DEBIAN"
    sed -i "s/0.0.0/${VERSION}/" "${TARGET_DIR}/${PACKAGE_NAME}/DEBIAN/control"

    mkdir -p ${PACKAGE_BINARY}
    cp "${TARGET_DIR}/ipxe/src/bin-x86_64-efi/ipxe.efi" ${PACKAGE_BINARY}
    cp "${TARGET_DIR}/ipxe/src/bin-x86_64-efi/snponly.efi" ${PACKAGE_BINARY}
    dpkg-deb --build --root-owner-group ${PACKAGE_NAME}

    mkdir -p "${RELEASE_DIR}"
    cp "${TARGET_DIR}/*.deb" "${RELEASE_DIR}/"
}

main "$@"
