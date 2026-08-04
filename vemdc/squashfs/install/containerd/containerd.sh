#!/usr/bin/env bash

apt install -y --no-install-recommends \
	fuse-overlayfs \
	containerd


mkdir -p /etc/containerd
containerd config default | tee /etc/containerd/config.toml > /dev/null

# Crucial step: Flip the SystemdCgroup flag from false to true
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

mkdir -p /var/lib/containerd/io.containerd.snapshotter.v1.fuse-overlayfs
mkdir -p /etc/containerd/conf.d

tee -a /etc/containerd/conf.d/99-custom-snapshotter.toml << 'EOF'

snapshotter = 'fuse-overlayfs'

[plugins]
  [plugins.'io.containerd.cri.v1.images']
    snapshotter = 'fuse-overlayfs'
    disable_snapshot_annotations = false
    discard_unpacked_layers = true

[proxy_plugins]
  [proxy_plugins."fuse-overlayfs"]
    type = "snapshot"
    address = "/run/containerd-fuse-overlayfs.sock"

[plugins."io.containerd.grpc.v1.cri".containerd]
  snapshotter = "fuse-overlayfs"

EOF


echo "net.ipv4.ip_forward = 1" | tee -a /etc/sysctl.d/k8s.conf
sysctl --system

