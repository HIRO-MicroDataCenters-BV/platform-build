#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
ETC_DIR="${ROOT_DIR}/etc"
TARGET_DIR="${ROOT_DIR}/target"
VERSION_PATH="${TARGET_DIR}/VERSION"
RELEASE_DIR="${TARGET_DIR}/release"
PACKAGE_STEM=frr
LIBYANG_VERSION=5.8.6
ARTIFACTS_DIR="${TARGET_DIR}/artifacts"

usage() {
    echo "Usage: $0 {install_dependencies, determine_version, build <arch: arm64, x86_64> <os: ubuntu-26.04>, package <arch: arm64|x86_64> <platform: amd64|arm64> <os: ubuntu-26.04>}"
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
            if [ $# -ne 3 ]; then
                usage
            fi
            build $2 $3
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

    DEBIAN_FRONTEND=noninteractive TZ=Etc/UTC apt install -y tzdata

    apt install -y\
        git \
        autoconf \
        automake \
        libtool \
        make \
        libreadline-dev \
        texinfo \
        pkg-config \
        libpam0g-dev \
        libjson-c-dev \
        bison \
        flex \
        libc-ares-dev \
        python3-dev \
        python3-sphinx \
        python3-pip \
        install-info \
        build-essential \
        libsnmp-dev \
        perl \
        libcap-dev \
        libelf-dev \
        libunwind-dev \
        protobuf-c-compiler \
        libprotobuf-c-dev \
        fakeroot \
        debhelper \
        devscripts

    pip3 install apkg

    echo "Dependencies installed."
}

build() {
    echo "Building binary..."
    ARCH="${1?Architecture not specified, e.g. arm64, x86_64}"
    PLATFORM_OS="${2?Platform OS, e.g. ubuntu-24.04|ubuntu-26.04}"

    build_libyang "${PLATFORM_OS}"
    # build_frr "${ARCH}"
}

build_libyang() {
    echo "Building libyang..."

    PLATFORM_OS="${1?Platform OS, e.g. ubuntu-24.04|ubuntu-26.04}"
    LIBYANG_TAG="v${LIBYANG_VERSION}"
    LIBYANG_DIR="${TARGET_DIR}/libyang"

    mkdir -p ${TARGET_DIR} ${ARTIFACTS_DIR}
    cd ${TARGET_DIR}

    git clone https://github.com/CESNET/libyang.git
    cd libyang
    git checkout ${LIBYANG_TAG}

    apkg build -i

    find "${LIBYANG_DIR}/pkg/pkgs/" -type f -name "*.deb" | while read -r file; do
        filename=$(basename "$file")
        new_filename="${filename%.deb}-${PLATFORM_OS}.deb"
        cp "$file" "${ARTIFACTS_DIR}/${new_filename}"
    done
}

build_frr() {
    echo "Building binary..."
    ARCH="${1?Architecture not specified, e.g. arm64, x86_64}"

    mkdir -p ${TARGET_DIR}
    cd ${TARGET_DIR}

    VERSION=$(cat ${VERSION_PATH})
    FRR_TAG="frr-${VERSION}"

    git clone https://github.com/FRRouting/frr.git
    cd frr
    git checkout ${FRR_TAG}

    echo "Building dependencies..."

    # mk-build-deps --install --remove debian/control

    # echo "Building frr..."
    # ./bootstrap.sh

    # ./configure \
    #     --prefix=/usr \
    #     --includedir=\${prefix}/include \
    #     --bindir=\${prefix}/bin \
    #     --sbindir=\${prefix}/lib/frr \
    #     --libdir=\${prefix}/lib/frr \
    #     --libexecdir=\${prefix}/lib/frr \
    #     --sysconfdir=/etc \
    #     --localstatedir=/var \
    #     --with-moduledir=\${prefix}/lib/frr/modules \
    #     --enable-configfile-mask=0640 \
    #     --enable-logfile-mask=0640 \
    #     --enable-snmp \
    #     --enable-multipath=256 \
    #     --enable-vrf \
    #     --enable-vpnv4 \
    #     --enable-vpnv6 \
    #     --enable-srv6 \
    #     --enable-user=frr \
    #     --enable-group=frr \
    #     --enable-vty-group=frrvty \
    #     --with-pkg-git-version \
    #     --with-pkg-extra-version=-HIROFRRVersion
    # make

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
    sed -i "s/amd64/${PLATFORM}/" "${TARGET_DIR}/${PACKAGE_NAME}/DEBIAN/control"

    mkdir -p ${PACKAGE_BINARY}
    cp "${TARGET_DIR}/ipxe/src/bin-${ARCH}-efi/ipxe.efi" ${PACKAGE_BINARY}
    cp "${TARGET_DIR}/ipxe/src/bin-${ARCH}-efi/snponly.efi" ${PACKAGE_BINARY}
    dpkg-deb --build --root-owner-group "${PACKAGE_NAME}"

    echo "Package is ready."
}

main "$@"
