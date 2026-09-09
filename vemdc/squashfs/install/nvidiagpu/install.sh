#!/usr/bin/env bash

INSTALL_DIR=/install

bash -c 'cat <<EOF > /etc/modprobe.d/blacklist-nouveau.conf
blacklist nouveau
options nouveau modeset=0
alias nouveau off
EOF'

apt install -y build-essential dkms
for kver in $(ls /lib/modules); do
  apt install -y "linux-headers-$kver"
done
dkms autoinstall
apt install -y nvidia-driver-580-open nvidia-utils-580

echo "Installing nvidia container toolkit"
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://nvidia.github.io/libnvidia-container/stable/deb/$(dpkg --print-architecture) /" | tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

apt update
apt install -y nvidia-container-toolkit

nvidia-ctk runtime configure --runtime=containerd --drop-in-config=/etc/containerd/conf.d/98-nvidia.toml
