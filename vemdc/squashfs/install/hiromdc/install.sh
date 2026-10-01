#!/usr/bin/env bash

INSTALL_DIR=/install

curl -fsSL https://hiro-microdatacenters-bv.github.io/packages-deb/repo.gpg | \
    tee /usr/share/keyrings/repo.gpg >/dev/null

echo "deb [signed-by=/usr/share/keyrings/repo.gpg] \
    https://hiro-microdatacenters-bv.github.io/packages-deb resolute main" |
    tee /etc/apt/sources.list.d/hiro-mds-packages-deb.list

cp ${INSTALL_DIR}/hiromdc/hiromdc.pref /etc/apt/preferences.d/hiromdc.pref

apt update -y

apt install -y \
    node-agent \
    containerd-fuse-overlayfs

rm /var/lib/node_agent/cert/server/*

cp ${INSTALL_DIR}/hiromdc/cert/ca.crt /var/lib/node_agent/cert/server
cp ${INSTALL_DIR}/hiromdc/cert/ca.key /var/lib/node_agent/cert/server

node_agent certs init-server

systemctl enable --now containerd-fuse-overlayfs
systemctl enable --now node_agent