#!/bin/bash

ROOT_DIR=./diskless/chroot
BUILD_DIR=./diskless/build

init() {

	mkdir -p ${ROOT_DIR}
	mkdir -p ${BUILD_DIR}

	rm -rf ${ROOT_DIR}/*

	debootstrap resolute ${ROOT_DIR} http://archive.ubuntu.com/ubuntu/
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
	cp -r ./install ${ROOT_DIR}
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
	cp -r ./install ${ROOT_DIR}
	chroot ${ROOT_DIR} /bin/bash
}

build() {
	# Extract Boot Assets & Compress to SquashFS

	rm ${BUILD_DIR}/*
	cp ${ROOT_DIR}/boot/vmlinuz ${BUILD_DIR}/vmlinuz
	cp ${ROOT_DIR}/boot/initrd.img ${BUILD_DIR}/initrd.img
	mksquashfs ${ROOT_DIR} ${BUILD_DIR}/filesystem.squashfs -comp xz 
	#-e boot
	chmod a+rw ${BUILD_DIR}/*
}

cleanup() {
	umount ${ROOT_DIR}/dev
	umount ${ROOT_DIR}/run
	umount ${ROOT_DIR}/proc
	umount ${ROOT_DIR}/sys	
}

upload() {
	scp ${BUILD_DIR}/* ubuntu@192.168.22.2:/home/ubuntu/matchbox_data/assets/ubuntu-26-live/
}

"$@"