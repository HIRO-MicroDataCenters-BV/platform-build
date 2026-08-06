# Configure Network

# launch head

```bash
    vemdc/bin/emdc.sh launch_head
```

# Install head

```bash
    ssh ubuntu@192.168.22.2
```

```bash
    sudo /mnt/platform-build/bin/head.sh install_dependencies
```

```bash
    sudo /mnt/platform-build/bin/head.sh setup
```

```bash
    /mnt/platform-build/bin/head.sh configure_kubectl
```

```bash
    kubeadm token create --print-join-command
```

## Launch Worker 

```bash
    vemdc/bin/emdc.sh launch_worker 01
```
