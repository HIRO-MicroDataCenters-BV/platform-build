#!/usr/bin/env bash

INSTALL_DIR=/install

wget -P /tmp https://github.com/containerd/fuse-overlayfs-snapshotter/releases/download/v2.1.7/containerd-fuse-overlayfs-2.1.7-linux-amd64.tar.gz
tar -C /usr/local/bin -xzf /tmp/containerd-fuse-overlayfs-2.1.7-linux-amd64.tar.gz

cp ${INSTALL_DIR}/containerd/containerd-fuse-overlayfs.service /etc/systemd/system/

systemctl enable --now containerd-fuse-overlayfs

