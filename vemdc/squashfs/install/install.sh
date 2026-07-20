#!/usr/bin/env bash

cat <<EOF > /etc/apt/sources.list
deb http://archive.ubuntu.com/ubuntu/ resolute main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu/ resolute-updates main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu/ resolute-security main restricted universe multiverse
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
	fuse-overlayfs \
	containerd \
	wget \
	curl \
	parted \
	vim

apt install -y --no-install-recommends \
	apt-transport-https \
	ca-certificates \
	gpg


mkdir -p /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.33/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

# Add the Kubernetes APT repository to your sources list
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.33/deb/ /" | tee /etc/apt/sources.list.d/kubernetes.list

apt update

apt install -y --no-install-recommends \
	kubelet \
	kubeadm \
	kubectl \
	cloud-init \
	cri-tools

# configure ssh
sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config

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

#### Configure containerd

/bin/bash /install/containerd/containerd-fuse-overlayfs.sh
/bin/bash /install/containerd/containerd.sh

#### init ramfs persistence #######
/bin/bash /install/initramfs/install.sh


### configure boot
# Configure Network Booting (initramfs)
update-initramfs -u -k all

apt-get clean
rm -rf /tmp/* /var/lib/apt/lists/*
echo "k8s-node-????-????" > /etc/hostname
echo "" > /etc/machine-id
exit



