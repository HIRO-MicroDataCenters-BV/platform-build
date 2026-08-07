#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
PLATFORM_BUILD_DIR="$(dirname "$ROOT_DIR")"
ETC_DIR="${ROOT_DIR}/etc"
UBUNTU_LIVE_ISO_DEST="${ROOT_DIR}/matchbox/matchbox_data/assets/ubuntu-26/"
TARGET_DIR="${ROOT_DIR}/target"
UBUNTU_CLOUD_IMG_DEST="${TARGET_DIR}"
SEED_ISO_BUNDLE_ROOT="${ETC_DIR}/seed"
MATCHBOX_WORKER_GROUP_ROOT="${ROOT_DIR}/matchbox/matchbox_data/groups"

usage() {
    echo "Usage: $0 {install_dependencies|create_network|launch_head|launch_worker 0X}"
    exit 1
}

main() {
    if [ $# -lt 1 ]; then
        usage
    fi
    case "$1" in
        install_dependencies)
            if [ $# -ne 1 ]; then
                usage
            fi
            install_dependencies
            ;;
        create_network)
            if [ $# -ne 1 ]; then
                usage
            fi
            create_network
            ;;
        launch_head)
            if [ $# -ne 1 ]; then
                usage
            fi
            launch_head
            ;;
        launch_worker)
            if [ $# -ne 2 ]; then
                usage
            fi
            launch_worker $2
            ;;
        *)
            echo "Error: Invalid command '$1'"
            usage
            ;;
    esac
}

install_dependencies() {
    echo "installing dependencies ..."
    mkdir ${UBUNTU_CLOUD_IMG_DEST}

    sudo apt install -y \
        wget \
        ovmf-generic \
        genisoimage \
        qemu-kvm \
        libvirt-daemon-system \
        libvirt-daemon-driver-qemu \
        virt-manager

    wget -P "${UBUNTU_LIVE_ISO_DEST}" https://releases.ubuntu.com/26.04/ubuntu-26.04-live-server-amd64.iso
    wget -P "${UBUNTU_CLOUD_IMG_DEST}" https://cloud-images.ubuntu.com/resolute/current/resolute-server-cloudimg-amd64.img

    echo "Dependencies installed."
}

create_network() {
    echo "Creating network ..."

    virsh net-define "${ETC_DIR}/emdc-net.xml"
    virsh net-start emdc-net

    echo "Network created."
}

delete_network() {
    echo "Deleting network ..."

    virsh net-stop emdc-net
    virsh net-delete emdc-net

    echo "Network deleted."
}

launch_head() {
    HEAD_NAME=network-provisioner
    MAC_ADDRESS="52:54:11:00:00:00"

    make_iso

    cp "${UBUNTU_CLOUD_IMG_DEST}/resolute-server-cloudimg-amd64.img" "${UBUNTU_CLOUD_IMG_DEST}/${HEAD_NAME}.img"
    qemu-img resize "${UBUNTU_CLOUD_IMG_DEST}/${HEAD_NAME}.img" +10G

    # copy image
    virt-install \
        --name=${HEAD_NAME} \
        --vcpus=4 \
        --memory=8192 \
        --memorybacking=source.type=memfd,access.mode=shared \
        --os-variant=ubuntu24.04 \
        --disk path="${UBUNTU_CLOUD_IMG_DEST}/${HEAD_NAME}.img",format=qcow2,bus=virtio,size=10 \
        --disk path="${TARGET_DIR}/seed.iso",device=cdrom \
        --network network=emdc-net,mac=${MAC_ADDRESS},model=virtio \
        --filesystem source=${PLATFORM_BUILD_DIR},target=root_dir,type=mount,driver.type=virtiofs \
        --import \
        --noautoconsole
}

setup_worker() {
    echo "Setting up worker ..."
    WORKER_NAME=$1
    WORKER_UUID=$2

    cat <<EOF | tee "${MATCHBOX_WORKER_GROUP_ROOT}/${WORKER_NAME}.json"
{
    "id": "${WORKER_NAME}",
    "name": "${WORKER_NAME}",
    "profile": "ubuntu-26-live",
    "selector": {    
        "uuid": "${WORKER_UUID}"
    },
    "metadata": {
        "hostname": "${WORKER_NAME}",
        "username": "ubuntu",
        "password_hash": "$6$PM/R4u/A3FVILWY8$.q7Syuoos7RDXUYzFTE1OGtIHzo41D88UWeri6T4x.V8h8qFwafzbiWkGL2ORh4BLvXtzVdqL0sYQF5j596UT0"
    }
}
EOF

}

launch_worker() {
    WORKER_ID=${1?Worker id is expected. e.g. 01}
    MAC_ADDRESS=$(printf '52:54:00:%02x:%02x:%02x' $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)))
    UUID=$(uuidgen)
    WORKER_NAME="worker-${WORKER_ID}"

    setup_worker "${WORKER_NAME}" "${UUID}"

    virt-install \
        --name=${WORKER_NAME} \
        --uuid=${UUID} \
        --vcpus=2 \
        --memory=8192 \
        --network network=emdc-net,mac=${MAC_ADDRESS},model=virtio \
        --boot loader=/usr/share/OVMF/OVMF_CODE_4M.fd,loader.readonly=yes,loader.type=pflash,nvram.template=/usr/share/OVMF/OVMF_VARS_4M.fd,bootmenu.enable=yes \
        --boot network \
        --disk size=20,bus=virtio,cache=none,discard=unmap \
        --os-variant=generic \
        --noautoconsole

}

make_iso() {
    mkdir -p "${TARGET_DIR}"
    sudo rm "${TARGET_DIR}/seed.iso"

    mkisofs -o "${TARGET_DIR}/seed.iso" \
        -J \
        -iso-level 3 \
        -allow-lowercase \
        -joliet-long \
        -input-charset utf8 \
        -rational-rock \
        -V cidata \
        "${SEED_ISO_BUNDLE_ROOT}"
}


main "$@"