#!/usr/bin/env bash

cat <<EOF > /etc/apt/sources.list
deb http://nl.archive.ubuntu.com/ubuntu/ resolute main restricted universe multiverse
deb http://nl.archive.ubuntu.com/ubuntu/ resolute-updates main restricted universe multiverse
deb http://nl.archive.ubuntu.com/ubuntu/ resolute-security main restricted universe multiverse
EOF

apt update 

apt install -y --no-install-recommends \
	live-boot \
	live-boot-initramfs-tools \
	linux-image-generic \
	linux-modules-7.0.0-27-generic \
	initramfs-tools \
	network-manager \
	openssh-server \
	wget \
	curl \
	parted \
	vim

# configure root
echo root:r | chpasswd

# configure ubuntu
useradd -m -s /bin/bash ubuntu
# 2. Add the user to the 'sudo' group
usermod -aG sudo ubuntu
# 3. Configure passwordless sudo for the ubuntu user
echo "ubuntu ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/ubuntu
chmod 0440 /etc/sudoers.d/ubuntu
mkdir -p /home/ubuntu/.ssh
chmod 700 /home/ubuntu/.ssh
echo ubuntu:u | chpasswd


#### Configure cloud init
echo "datasource_list: [ NoCloud ]" > /etc/cloud/cloud.cfg.d/90_datasource_nocloud.cfg
# Enable cloud-init services
systemctl enable cloud-init-local.service cloud-config.service cloud-final.service
