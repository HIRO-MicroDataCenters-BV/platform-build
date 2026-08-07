# Install dependencies

```bash
    vemdc/bin/emdc.sh install_dependencies
```

# Configure Virtual Network

```bash
    vemdc/bin/emdc.sh create_network
```

# Boot Head Node

```bash
    vemdc/bin/emdc.sh launch_head
```

## Install head

```bash
    ssh ubuntu@192.168.22.2
```
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

# Boot Worker Node

## Launch Worker 

```bash
    vemdc/bin/emdc.sh launch_worker 01
```

## Execute join command on a worker
