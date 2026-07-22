#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
ETC_DIR="${ROOT_DIR}/etc"
TARGET_DIR="${ROOT_DIR}/target"

usage() {
    echo "Usage: $0 {install_dependencies,build,package}"
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
        *)
            echo "Error: Invalid command '$1'"
            usage
            ;;
    esac
}

install_dependencies() {
    sudo apt install -y
        make \
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

package() {
    VERSION=0.1.0
    PACKAGE_NAME="emdc-ipxe-${VERSION}_amd64"
    cd ${TARGET_DIR}
    mkdir -p "${TARGET_DIR}/${PACKAGE_NAME}/DEBIAN"
    cp ${ROOT_DIR}/debian/* "${TARGET_DIR}/${PACKAGE_NAME}/DEBIAN"
    dpkg-deb --build --root-owner-group ${PACKAGE_NAME}
}

main "$@"
