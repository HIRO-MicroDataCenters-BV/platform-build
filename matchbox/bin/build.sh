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
            if [ $# -ne 2 ]; then
                usage
            fi
            install_dependencies $2
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
    ARCH="${1?Architecture not specified, e.g. arm64, amd64}"

    apt install -y \
        git \
        gcc \
        make \
        liblzma-dev \
        build-essential \
        devscripts \
        debhelper \
        wget

    wget https://go.dev/dl/go1.24.0.linux-${ARCH}.tar.gz
    rm -rf /usr/local/go && tar -C /usr/local -xzf go1.24.0.linux-${ARCH}.tar.gz

    # Ensure /usr/local/go/bin is in your PATH
    export PATH=$PATH:/usr/local/go/bin
    echo 'export PATH="$PATH"' >> ~/.bashrc
    source ~/.bashrc

    echo "Dependencies installed."
}

build() {
    echo "Building binary..."
    ARCH="${1?Architecture not specified, e.g. arm64, x86_64}"

    export PATH=$PATH:/usr/local/go/bin

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
    ROOT_PKG_DIR="${TARGET_DIR}/${PACKAGE_NAME}"    

    PACKAGE_BIN_DIR="${ROOT_PKG_DIR}/usr/local/bin/"
    SYSTEMD_SVC="${ROOT_PKG_DIR}/etc/systemd/system"
    PACKAGE_DOCS="${ROOT_PKG_DIR}/usr/local/share/doc/matchbox/"
    PACKAGE_EXAMPLES="${ROOT_PKG_DIR}/usr/local/share/doc/matchbox/examples"
    PACKAGE_SCRIPTS="${ROOT_PKG_DIR}/usr/local/share/matchbox/scripts/"
    DATA_ASSETS_DIR="${ROOT_PKG_DIR}/var/lib/matchbox"
    ETC_DIR="${ROOT_PKG_DIR}/etc/matchbox"

    rm -rf "${ROOT_PKG_DIR}"

    # Package artifacts
    mkdir -p "${ROOT_PKG_DIR}/DEBIAN"
    cp ${ROOT_DIR}/debian/* "${ROOT_PKG_DIR}/DEBIAN"
    sed -i "s/0.0.0/${VERSION}/" "${ROOT_PKG_DIR}/DEBIAN/control"
    sed -i "s/amd64/${PLATFORM}/" "${ROOT_PKG_DIR}/DEBIAN/control"
    chmod 755 "${ROOT_PKG_DIR}/DEBIAN/preinst" \
              "${ROOT_PKG_DIR}/DEBIAN/postinst" \
              "${ROOT_PKG_DIR}/DEBIAN/postrm" 2>/dev/null || true

    # Binary
    mkdir -p ${PACKAGE_BIN_DIR}
    cp "${BUILD_DIR}/matchbox" "${PACKAGE_BIN_DIR}/"
    chmod 755 "${PACKAGE_BIN_DIR}/matchbox"

    # systemd service
    mkdir -p ${SYSTEMD_SVC}
    cp "${BUILD_DIR}/contrib/systemd/matchbox.service" "${SYSTEMD_SVC}/"
    chmod 644 "${SYSTEMD_SVC}/matchbox.service"

    # docs, examples, scripts
    mkdir -p "${PACKAGE_DOCS}" "${PACKAGE_EXAMPLES}" "${PACKAGE_SCRIPTS}"
    cp -r "${BUILD_DIR}/docs/"* "${PACKAGE_DOCS}/"
    cp -r "${BUILD_DIR}/examples/"* "${PACKAGE_EXAMPLES}/"
    cp -r "${BUILD_DIR}/scripts/"* "${PACKAGE_SCRIPTS}/"
    chmod -R 755 "${PACKAGE_SCRIPTS}"

    mkdir -p "${DATA_ASSETS_DIR}/assets"
    mkdir -p "${ETC_DIR}"

    # Building package
    dpkg-deb --build --root-owner-group "${PACKAGE_NAME}"

    echo "Package is ready."
}

main "$@"
