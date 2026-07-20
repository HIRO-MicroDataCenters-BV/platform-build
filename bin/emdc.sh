#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
ETC_DIR="${ROOT_DIR}/etc"
UBUNTU_LIVE_ISO_DEST="${ROOT_DIR}/matchbox/matchbox_data/assets/ubuntu-26/"
TARGET_DIR="${ROOT_DIR}/target"
UBUNTU_CLOUD_IMG_DEST="${TARGET_DIR}"
SEED_ISO_BUNDLE_ROOT="${ETC_DIR}/seed"

usage() {
    echo "Usage: $0 {install_dependencies|create_network|launch_head|launch_worker|cleanup}"
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
        create_network)
            create_network
            ;;
        launch_head)
            launch_head
            ;;
        launch_worker)
            launch_worker
            ;;
        cleanup)
            cleanup
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
        genisoimage

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
    HEAD_NAME=network-provisioner-test
    MAC_ADDRESS="52:54:11:00:00:00"    

    cp ${UBUNTU_CLOUD_IMG_DEST}/resolute-server-cloudimg-amd64.img ${UBUNTU_CLOUD_IMG_DEST}/network-provisioner-test.img
    qemu-img resize ${UBUNTU_CLOUD_IMG_DEST}/network-provisioner-test.img +10G

    make_iso

    # copy image
    virt-install \
        --name=${HEAD_NAME} \
        --vcpus=4 \
        --memory=8192 \
        --memorybacking=source.type=memfd,access.mode=shared \
        --os-variant=ubuntu24.04 \
        --disk path=${UBUNTU_CLOUD_IMG_DEST}/network-provisioner-test.img,format=qcow2,bus=virtio,size=10 \
        --disk path=${TARGET_DIR}/seed.iso,device=cdrom \
        --network network=pxe-mesh,mac=${MAC_ADDRESS},model=virtio \
        --filesystem source=${ROOT_DIR},target=root_dir,type=mount,driver.type=virtiofs \
        --import \
        --noautoconsole
# TODO network id
#   --network network=emdc-net,mac=${MAC_ADDRESS},model=virtio \        
}

setup_worker() {
    echo "setup worker"
}

launch_worker() {
    MAC_ADDRESS="52:54:00:fa:19:bc"
    UUID="7582474c-1a40-4c14-874c-a8b32fee31ad"
    WORKER_NAME="worker-01"

    virt-install \
        --name=${WORKER_NAME} \
        --uuid=${UUID} \
        --vcpus=2 \
        --memory=8192 \
        --network network=pxe-mesh,mac=${MAC_ADDRESS},model=virtio \
        --boot loader=/usr/share/OVMF/OVMF_CODE_4M.fd,loader.readonly=yes,loader.type=pflash,nvram.template=/usr/share/OVMF/OVMF_VARS_4M.fd,bootmenu.enable=yes \
        --boot network \
        --disk size=20,bus=virtio,cache=none,discard=unmap \
        --os-variant=generic \
        --noautoconsole
# TODO network id
#--network network=emdc-net,mac=${MAC_ADDRESS},model=virtio \
}

make_iso() {
    mkdir -p "${TARGET_DIR}"
    rm "${TARGET_DIR}/seed.iso"

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

cleanup() {
    echo "cleaning up..."

    delete_network

    echo "clean up is done."
}

main "$@"