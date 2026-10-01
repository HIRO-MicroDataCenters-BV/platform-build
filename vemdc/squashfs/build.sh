#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT_DIR="${SCRIPT_DIR}/.."
ROOT_DIR=${SCRIPT_DIR}/diskless/chroot
BUILD_DIR=${SCRIPT_DIR}/diskless/build
CA_CERT_SRC_DIR="${PROJECT_ROOT_DIR}/etc/node_agent"
CA_CERT_INSTALL_DIR="${ROOT_DIR}/install/hiromdc/cert"

DISTRO=resolute
DISTRO_URL=http://nl.archive.ubuntu.com/ubuntu/

init() {

	mkdir -p ${ROOT_DIR}
	mkdir -p ${BUILD_DIR}

	rm -rf ${ROOT_DIR}/*

	debootstrap ${DISTRO} ${ROOT_DIR} ${DISTRO_URL}
}

install() {
	umount ${ROOT_DIR}/dev
	umount ${ROOT_DIR}/run
	umount ${ROOT_DIR}/proc
	umount ${ROOT_DIR}/sys	

	# Mount Virtual Filesystems
	mount --bind /dev ${ROOT_DIR}/dev
	mount --bind /run ${ROOT_DIR}/run
	mount -t proc proc ${ROOT_DIR}/proc
	mount -t sysfs sysfs ${ROOT_DIR}/sys

	# Chroot and Configure Repositories
	mkdir -p "${CA_CERT_INSTALL_DIR}"
	cp ${CA_CERT_SRC_DIR}/ca.* "${CA_CERT_INSTALL_DIR}/"
	cp -r ${SCRIPT_DIR}/install ${ROOT_DIR}
	chroot ${ROOT_DIR} /bin/bash /install/install.sh
}

enter() {
	umount ${ROOT_DIR}/dev
	umount ${ROOT_DIR}/run
	umount ${ROOT_DIR}/proc
	umount ${ROOT_DIR}/sys	

	# Mount Virtual Filesystems
	mount --bind /dev ${ROOT_DIR}/dev
	mount --bind /run ${ROOT_DIR}/run
	mount -t proc proc ${ROOT_DIR}/proc
	mount -t sysfs sysfs ${ROOT_DIR}/sys

	# Chroot and Configure Repositories
	cp -r ${SCRIPT_DIR}/install ${ROOT_DIR}
	chroot ${ROOT_DIR} /bin/bash
}

build() {
	# Extract Boot Assets & Compress to SquashFS

	rm ${BUILD_DIR}/*
	cp ${ROOT_DIR}/boot/vmlinuz ${BUILD_DIR}/vmlinuz
	cp ${ROOT_DIR}/boot/initrd.img ${BUILD_DIR}/initrd.img

	mksquashfs ${ROOT_DIR} ${BUILD_DIR}/filesystem.squashfs -comp xz 

	chmod a+rw ${BUILD_DIR}/*
}

cleanup() {
	umount ${ROOT_DIR}/dev
	umount ${ROOT_DIR}/run
	umount ${ROOT_DIR}/proc
	umount ${ROOT_DIR}/sys	
}

upload() {
	sudo chown ${USER}:${USER} ${BUILD_DIR}/*
	cp ${BUILD_DIR}/* ${PROJECT_ROOT_DIR}/matchbox/matchbox_data/assets/ubuntu-26-live/
	echo "kernel, initramfs, squashfs have been copied to matchbox assets."
	ls -ltra ${PROJECT_ROOT_DIR}/matchbox/matchbox_data/assets/ubuntu-26-live/*
}

"$@"