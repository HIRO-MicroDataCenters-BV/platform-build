#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
ETC_DIR="${ROOT_DIR}/etc"
TARGET_DIR="${ROOT_DIR}/target"
VERSION_PATH="${TARGET_DIR}/VERSION"
RELEASE_DIR="${TARGET_DIR}/release"
PACKAGE_STEM=matchbox

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

    wget https://go.dev/dl/go1.24.0.linux-amd64.tar.gz
    sudo rm -rf /usr/local/go && sudo tar -C /usr/local -xzf go1.24.0.linux-amd64.tar.gz

    # Ensure /usr/local/go/bin is in your PATH
    export PATH=$PATH:/usr/local/go/bin

    echo "Dependencies installed."
}

build() {
    echo "Building binary..."
    ARCH="${1?Architecture not specified, e.g. arm64, x86_64}"

    mkdir -p ${TARGET_DIR}
    cd ${TARGET_DIR}

    VERSION=$(cat ${VERSION_PATH})
    MATCHBOX_TAG="v${VERSION}"    

    git clone https://github.com/poseidon/matchbox.git
    cd ${TARGET_DIR}/matchbox
    git checkout "${MATCHBOX_TAG}"

    make release

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
    SRC_PACKAGE_NAME="${PACKAGE_STEM}-v${VERSION}-linux-${PLATFORM}"
    BUILD_DIR="${TARGET_DIR}/matchbox/_output/${SRC_PACKAGE_NAME}"

    PACKAGE_NAME="${PACKAGE_STEM}-v${VERSION}-linux-${PLATFORM}-${OS_VERSION}"

    PACKAGE_BINARY="${TARGET_DIR}/${PACKAGE_NAME}/usr/local/bin/${PACKAGE_STEM}"
    SYSTEMD_SVC="${TARGET_DIR}/${PACKAGE_NAME}/etc/systemd/system"    
    PACKAGE_DOCS="${TARGET_DIR}/${PACKAGE_NAME}/usr/local/share/doc/matchbox/"
    PACKAGE_EXAMPLES="${TARGET_DIR}/${PACKAGE_NAME}/usr/local/share/doc/matchbox/examples"
    PACKAGE_SCRIPTS="${TARGET_DIR}/${PACKAGE_NAME}//usr/local/share/matchbox/scripts/"
    DATA_ASSETS_DIR="${TARGET_DIR}/${PACKAGE_NAME}/var/lib/matchbox"

    # Package artifacts
    mkdir -p "${TARGET_DIR}/${PACKAGE_NAME}/DEBIAN"
    cp ${ROOT_DIR}/debian/* "${TARGET_DIR}/${PACKAGE_NAME}/DEBIAN"
    sed -i "s/0.0.0/${VERSION}/" "${TARGET_DIR}/${PACKAGE_NAME}/DEBIAN/control"

    # Binary
    mkdir -p ${PACKAGE_BINARY}
    cp "${BUILD_DIR}/matchbox" "${PACKAGE_BINARY}/matchbox"

    # systemd service
    mkdir -p ${SYSTEMD_SVC}
    cp "${BUILD_DIR}/contrib/systemd/matchbox.service" "${SYSTEMD_SVC}"

    mkdir -p ${PACKAGE_DOCS}
    cp -r "${BUILD_DIR}/docs/" "${PACKAGE_DOCS}"

    mkdir -p ${PACKAGE_EXAMPLES}
    cp -r "${BUILD_DIR}/examples/" "${PACKAGE_EXAMPLES}"

    mkdir -p ${PACKAGE_SCRIPTS}
    cp -r "${BUILD_DIR}/scripts/" "${PACKAGE_SCRIPTS}"

    # Building package
    dpkg-deb --build --root-owner-group "${PACKAGE_NAME}"

    echo "Package is ready."
}

main "$@"
