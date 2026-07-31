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
    echo "Usage: $0 {install_dependencies, determine_version, build <os: ubuntu-26.04>}"
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
        *)
            echo "Error: Invalid command '$1'"
            usage
            ;;
    esac
}

install_dependencies() {
    echo "Install dependencies ..."

    apt install -y tzdata

    apt install -y apt-utils

    apt install -y\
        git \
        sudo \
        git-buildpackage \
        equivs \
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

    pip3 install --break-system-packages apkg

    echo "Dependencies installed."
}

build() {
    echo "Building binary..."
    PLATFORM_OS="${1?Platform OS, e.g. ubuntu-24.04|ubuntu-26.04}"

    build_libyang "${PLATFORM_OS}"
    build_frr "${PLATFORM_OS}"
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

    echo "Adding extra flags to debian/rules"
    sed -i '/--enable-snmp \\/a \
\t\t--enable-vrf \\\
\t\t--enable-vpnv4 \\\
\t\t--enable-vpnv6 \\\
\t\t--enable-srv6 \\\
\t\t--with-pkg-extra-version=-HIROFRRVersion \\' debian/rules

    echo "Building dependencies..."

    sudo mk-build-deps --install --remove debian/control

    echo "Building frr..."

    gbp buildpackage \
        --git-builder=dpkg-buildpackage \
        --git-debian-branch="${FRR_TAG}" \
        --git-ignore-branch \
        --git-ignore-new -uc -us -b -j$(nproc)

    find "${TARGET_DIR}" -type f -name "*.deb" | while read -r file; do
        filename=$(basename "$file")
        new_filename="${filename%.deb}-${PLATFORM_OS}.deb"
        cp "$file" "${ARTIFACTS_DIR}/${new_filename}"
    done

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

main "$@"
