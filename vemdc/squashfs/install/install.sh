#!/usr/bin/env bash

#### Configure ubuntu system
/bin/bash /install/ubuntu/install.sh

#### Configure HIRO packages
/bin/bash /install/hiromdc/install.sh

#### Configure containerd
/bin/bash /install/containerd/containerd.sh

#### Configure kubernetes
/bin/bash /install/kubernetes/install.sh

#### initramfs - persistence
/bin/bash /install/initramfs/install.sh

### configure boot
# Configure Network Booting (initramfs)
update-initramfs -u -k all

apt-get clean
rm -rf /tmp/* /var/lib/apt/lists/*
echo "k8s-node-????-????" > /etc/hostname
echo "" > /etc/machine-id
rm -f /var/lib/dbus/machine-id
exit



