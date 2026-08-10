# Manual install and configuration on baremetal emdc

# Configuring Head Node

## Checkout and configure platform-build repo

```bash
    git clone https://github.com/HIRO-MicroDataCenters-BV/platform-build.git /mnt/platform-build
```

### Configure netplan
    Configure mac address and interface name of the primary interface and copy the netplan config
```bash
    sudo cp /mnt/platform-build/emdc/etc/00-installer-config.yaml /etc/netplan/
    sudo netplan apply
```

### Configure DHCP4/6

Conifgure dhcp 4 and 6.
```bash
    /mnt/platform-build/vemdc/etc/kea/kea-dhcp4.conf
    /mnt/platform-build/vemdc/etc/kea/kea-dhcp6.conf
```

Change ipxe.efi to snponly.efi in all bootname_url config entries. This is for the cases when ipxe does not have native drivers (e.g. amd-xgbe) and therefore native uefi drivers preferred.

    http://192.168.22.2:8080/assets/ipxe.efi
    http://[fd00:22::2]:8080/assets/ipxe.efi

Change network interface to the primary one on the module in the interface-config and subnet section, e.g. enp3s0f4

### Configure RADVD network interface

Configure the primary interface here `/mnt/platform-build/vemdc/etc/radvd/radvd.conf`

### Configure console terminal

Add kernel arg "console=ttyS0,115200n8" to the list of args to live profile `/mnt/platform-build/vemdc/matchbox/matchbox_data/profiles/ubuntu-26-live.json`

### build and copy squashfs artifacts

Build squashfs. Check readme `/mnt/platform-build/vemdc/squashfs/README.md` for details. 
Copy filesystem.squashfs, vmlinuz and initrd.img to `/mnt/platform-build/vemdc/matchbox/matchbox_data/assets/ubuntu-26-live`

## Install and configure components

### Install dependencies to head node
```bash
    sudo /mnt/platform-build/vemdc/bin/head.sh install_dependencies
```

### Configure Netboot, DHCP, Matchbox and other services
```bash
    sudo /mnt/platform-build/vemdc/bin/head.sh setup
```

### Configure kubeconfig
```bash
    /mnt/platform-build/vemdc/bin/head.sh configure_kubectl
```

### Generate join command
```bash
    sudo kubeadm token create --print-join-command
```

the kubeadm will print join command similar to the one below

```bash
    kubeadm join 192.168.22.2:6443 \
        --token g6ukfz.hatp8igrhpxqf817 \
        --discovery-token-ca-cert-hash sha256:bf717f7...c51c14
```

Tip: Resetting kubernetes to initial state

```bash
    sudo kubeadm reset -f
```

# Configure Worker 

## Configure worker group profile

Configure node profile here `/mnt/platform-build/vemdc/matchbox/matchbox_data/groups/`.

See example: `/mnt/platform-build/vemdc/matchbox/matchbox_data/groups/example-worker.json`.

## Execute join command on a worker

```bash
    sudo kubeadm join 192.168.22.2:6443 \
        --token g6ukfz.hatp8igrhpxqf817 \
        --discovery-token-ca-cert-hash sha256:bf717f7...c51c14
```
