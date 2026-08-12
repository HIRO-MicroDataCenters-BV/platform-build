# Virtual EMDC environment

# Prerequisites

- ubuntu 26.04 (tested)
- head vm - 4 cpu, 8gb RAM, 20 Gb
- worker vm - minimal 4 cpu core, 8Gb RAM, 20Gb disk drive

# Host node setup

## Install dependencies

```bash
    vemdc/bin/emdc.sh install_dependencies
```

## Configure Virtual Network

```bash
    vemdc/bin/emdc.sh create_network
```

## Build Worker Squash Filesystem

Build squashfs. Check [README.md](squashfs/README.md) for details. 

# Boot Head Node

```bash
    vemdc/bin/emdc.sh launch_head
```

## Install head node VM

```bash
    ssh ubuntu@192.168.22.2
```
## Install dependencies to head node
```bash
    sudo /mnt/platform-build/vemdc/bin/head.sh install_dependencies
```

## Configure Netboot, DHCP, Matchbox and other services
```bash
    sudo /mnt/platform-build/vemdc/bin/head.sh setup
```

## Configure kubeconfig
```bash
    /mnt/platform-build/vemdc/bin/head.sh configure_kubectl
```

## Generate join command
```bash
    sudo kubeadm token create --print-join-command
```

the kubeadm will print join command similar to the one below

```bash
    kubeadm join 192.168.22.2:6443 \
        --token g6ukfz.hatp8igrhpxqf817 \
        --discovery-token-ca-cert-hash sha256:bf717f7...c51c14
```


# Worker Node VM

## Launch Worker 

```bash
    vemdc/bin/emdc.sh launch_worker 01
```

## Execute join command on a worker

```bash
    sudo kubeadm join 192.168.22.2:6443 \
        --token g6ukfz.hatp8igrhpxqf817 \
        --discovery-token-ca-cert-hash sha256:bf717f7...c51c14
```

