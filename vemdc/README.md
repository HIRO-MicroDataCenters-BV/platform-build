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

# Boot Nvidia GPU Worker Node

## Configure Dedicated Nvidia GPU on the Host  

Note! if the host system is used with display then several GPUs or sliced GPU are required. 
It is not possible to passthrough a GPU to VM and at the same time serve the display of the host system.
The GPU being passed-through to VM is inaccessible to the host system.

### 1. List GPUs with their device ids
```
lspci -nn
```

The example of output is below:

```
 ...

97:00.0 VGA compatible controller [0300]: NVIDIA Corporation TU117GLM [Quadro T1000 Mobile] [10de:1ff9] (rev a1)
97:00.1 Audio device [0403]: NVIDIA Corporation Device [10de:10fa] (rev a1)
 ...

```

### 1. Make sure vfio driver is loaded

Add the following drivers to the `/etc/initramfs-tools/modules`:

```
vfio
vfio_iommu_type1
vfio_pci
vfio_virqfd
```

### 2. make sure that nvidia GPU is initialized by vfio driver

Add the following configuration to the `/etc/modprobe.d/vfio.conf` (make sure device ids are GPU device ids):

```
options vfio-pci ids=10de:1ff9,10de:10fa
softdep nvidia pre: vfio-pci
softdep nouveau pre: vfio-pci
```
### 3 Update initial filesystem

```
    sudo update-initramfs -u -k all
```

### 4 Reboot host system and ensure that vfi driver is correctly loaded:

```
lspci -nnk | grep -A 3 -i nvidia

--
97:00.0 VGA compatible controller [0300]: NVIDIA Corporation TU117GLM [Quadro T1000 Mobile] [10de:1ff9] (rev a1)
        Subsystem: Advantech Co. Ltd Device [13fe:00a9]
        Kernel driver in use: vfio-pci
        Kernel modules: nvidiafb, nouveau, nvidia_drm, nvidia
97:00.1 Audio device [0403]: NVIDIA Corporation Device [10de:10fa] (rev a1)
        Subsystem: Advantech Co. Ltd Device [13fe:00a9]
        Kernel driver in use: vfio-pci
        Kernel modules: snd_hda_intel
```

## Launch GPU Worker 

Launch worker node VM with host GPU passthrough, specifying PCI ids of GPU and audio device

```bash
    vemdc/bin/emdc.sh launch_gpu_worker 0X 97:00.0 97:00.1
```

## Execute join command on a worker

```bash
    sudo kubeadm join 192.168.22.2:6443 \
        --token g6ukfz.hatp8igrhpxqf817 \
        --discovery-token-ca-cert-hash sha256:bf717f7...c51c14
```
