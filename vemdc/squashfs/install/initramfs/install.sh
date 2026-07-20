#!/usr/bin/env bash

INSTALL_DIR=/install

mkdir -p /etc/initramfs-tools/scripts/live-premount

cp ${INSTALL_DIR}/initramfs/bootstrap_storage_hook /etc/initramfs-tools/hooks/bootstrap_storage_hook
cp ${INSTALL_DIR}/initramfs/bootstrap_storage /etc/initramfs-tools/scripts/live-premount/bootstrap_storage

chmod +x /etc/initramfs-tools/hooks/bootstrap_storage_hook
chmod +x /etc/initramfs-tools/scripts/live-premount/bootstrap_storage

cp ${INSTALL_DIR}/initramfs/wait-for-ipv6 /etc/initramfs-tools/scripts/init-premount/wait-for-ipv6
chmod +x /etc/initramfs-tools/scripts/init-premount/wait-for-ipv6