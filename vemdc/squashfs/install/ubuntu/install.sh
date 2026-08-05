#!/usr/bin/env bash

cat <<EOF > /etc/apt/sources.list
deb http://nl.archive.ubuntu.com/ubuntu/ resolute main restricted universe multiverse
deb http://nl.archive.ubuntu.com/ubuntu/ resolute-updates main restricted universe multiverse
deb http://nl.archive.ubuntu.com/ubuntu/ resolute-security main restricted universe multiverse
EOF

apt update && apt upgrade -y

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

# configure user ubuntu
useradd -m -s /bin/bash -U ubuntu
echo ubuntu:u | chpasswd
passwd -u ubuntu

chage -E -1 -M 99999 -W 7 -I -1 ubuntu

# 2. Add the user to the 'sudo' group
usermod -aG sudo ubuntu

# 3. Configure passwordless sudo for the ubuntu user
echo "ubuntu ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/ubuntu
chmod 0440 /etc/sudoers.d/ubuntu

mkdir -p /home/ubuntu/.ssh
chmod 700 /home/ubuntu/.ssh
chown -R ubuntu:ubuntu /home/ubuntu
chmod 755 /home/ubuntu


#### Configure cloud init
mkdir -p /etc/cloud/cloud.cfg.d/
echo "datasource_list: [ NoCloud ]" > /etc/cloud/cloud.cfg.d/90_datasource_nocloud.cfg
# cat << 'EOF' > /etc/cloud/cloud.cfg.d/99-disable-password-lock.cfg
# ssh_pwauth: true
# lock_passwd: false
# chpasswd:
#   expire: false
# EOF

# Enable cloud-init services
systemctl enable cloud-init-local.service cloud-config.service cloud-final.service

# # purge cloud init
# apt-get purge -y cloud-init
# rm -rf /etc/cloud/ /var/lib/cloud/