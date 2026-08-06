#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
TARGET="${ROOT_DIR}/target"
ETC_DIR="${ROOT_DIR}/etc"

usage() {
    echo "Usage: $0 {install_dependencies|setup|configure_kubectl}"
    exit 1
}

main() {
    if [ $# -ne 1 ]; then
        usage
    fi

    case "$1" in
        install_dependencies)
            install_dependencies
            ;;
        setup)
            setup
            ;;
        configure_kubectl)
            configure_kubectl
            ;;
        cleanup)
            cleanup
            ;;
        *)
            echo "Error: Invalid command '$1'"
            usage
            ;;
    esac
}

install_dependencies() {
    echo "installing dependencies ..."

    ## Installing HiroMDC repo

    curl -fsSL https://hiro-microdatacenters-bv.github.io/packages-deb/repo.gpg | \
        tee /usr/share/keyrings/repo.gpg >/dev/null

    echo "deb [signed-by=/usr/share/keyrings/repo.gpg] \
        https://hiro-microdatacenters-bv.github.io/packages-deb resolute main" |
        tee /etc/apt/sources.list.d/hiro-mds-packages-deb.list

    sudo touch /etc/apt/preferences.d/hiromdc.pref

    cat <<EOF | sudo tee /etc/apt/preferences.d/hiromdc.pref    
Explanation: Prioritize custom packages from HiroMDC repository
Package: *
Pin: release o=HiroMDC
Pin-Priority: 900
EOF

    ### Installing general dependencies ###
    apt update && apt upgrade -y

    apt install -y \
        wget \
        radvd \
        kea-dhcp4-server \
        kea-dhcp6-server \
        containerd \
        matchbox \
        ipxe-boot \
        libvirt-daemon \
        node-agent

    ### Installing kubernetes ###
    apt-get install -y apt-transport-https ca-certificates curl gpg

    # Add the Kubernetes repository signing key
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.33/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

    # Add the Kubernetes APT repository to your sources list
    echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.33/deb/ /" | tee /etc/apt/sources.list.d/kubernetes.list

    # Install the binaries
    apt update
    apt-get install -y kubelet kubeadm kubectl

    echo "Dependencies installed."
}

configure_node_agent() {
    echo "Node agent..."

    sudo systemctl enable --now libvirtd
    sudo systemctl restart libvirtd
    sudo systemctl enable --now node-agent
    sudo systemctl restart node-agent

    echo "Node agent configured."
}

configure_ipxe_boot() {
    echo "Configuring IPXE boot..."

    MATCHBOX_DIR="${ROOT_DIR}/matchbox/matchbox_data"

    cp /usr/lib/ipxe-boot/ipxe.efi ${MATCHBOX_DIR}/assets/ipxe.efi
    cp /usr/lib/ipxe-boot/snponly.efi ${MATCHBOX_DIR}/assets/snponly.efi

    echo "IPXE boot configured."
}

configure_matchbox() {
    echo "Configuring matchbox..."

    sudo cp "${ETC_DIR}/matchbox/matchbox.service" /etc/systemd/system/matchbox.service
    sudo systemctl daemon-reload
    sudo systemctl enable --now matchbox
    sudo systemctl restart matchbox

    echo "Matchbox configured."
}

install_k9s() {
    echo "Installing k9s..."

    wget "https://github.com/derailed/k9s/releases/latest/download/k9s_Linux_amd64.tar.gz" -O /tmp/k9s.tar.gz
    tar -xzf /tmp/k9s.tar.gz -C /tmp/
    sudo mv /tmp/k9s /usr/local/bin/k9s
    sudo chmod +x /usr/local/bin/k9s

    echo "k9s installed"
}

configure_kea() {
    echo "Installing kea dhcp4/dhcp6..."
    cp ${ETC_DIR}/kea/* /etc/kea/
    systemctl enable kea-dhcp4-server
    systemctl restart kea-dhcp4-server
    systemctl enable kea-dhcp6-server
    systemctl restart kea-dhcp6-server

    echo "Kea dhcp4/dhcp6 is installed"
}

configure_radvd() {
    echo "Installing radvd ..."
    sysctl -w net.ipv6.conf.all.forwarding=1
    cp ${ETC_DIR}/radvd/radvd.conf /etc/radvd.conf
    systemctl enable radvd
    echo "Radvd is installed"
}


configure_containerd() {
    echo "Installing containerd"
    # Generate default configuration
    mkdir -p /etc/containerd
    containerd config default | tee /etc/containerd/config.toml > /dev/null

    # Crucial: Configure containerd to use the systemd cgroup driver
    sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml

    # Restart and enable containerd
    systemctl enable containerd
    systemctl restart containerd

    echo "Containerd is installed."
}

configure_kubernetes() {
    echo "Installing kubernetes..."
    swapoff -a
    sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

    cat <<EOF | tee /etc/modules-load.d/k8s.conf
    overlay
    br_netfilter
EOF

    # Configure sysctl parameters
    cat <<EOF | tee /etc/sysctl.d/k8s.conf
    net.bridge.bridge-nf-call-iptables  = 1
    net.bridge.bridge-nf-call-ip6tables = 1
    net.ipv4.ip_forward                 = 1
EOF

    # Apply sysctl parameters without rebooting
    sysctl --system

    kubeadm init \
        --apiserver-advertise-address=192.168.22.2 \
        --pod-network-cidr=10.10.0.0/16 \
        --cri-socket=unix:///run/containerd/containerd.sock

    mkdir -p $HOME/.kube
    cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
    chown $(id -u):$(id -g) $HOME/.kube/config

    kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/calico.yaml

    kubectl get nodes
    kubectl get pods -n kube-system

    kubeadm token create --print-join-command

    echo "Kubernetes installed"    
}

setup() {
    configure_kea
    configure_radvd
    configure_containerd
    configure_kubernetes
    configure_matchbox
    configure_ipxe_boot
    configure_node_agent
    install_k9s
}

configure_kubectl() {
    mkdir -p $HOME/.kube
    sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
    sudo chown $(id -u):$(id -g) $HOME/.kube/config
}

main "$@"