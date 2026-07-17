#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
TARGET="${ROOT_DIR}/target"
ETC_DIR="${ROOT_DIR}/etc"

usage() {
    echo "Usage: $0 {install_dependencies|setup|cleanup}"
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

    ### Installing general dependencies ###
    sudo apt install -y wget radvd kea-dhcp4-server kea-dhcp6-server

    ### Installing kubernetes ###
    apt-get install -y apt-transport-https ca-certificates curl gpg

    # Add the Kubernetes repository signing key
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

    # Add the Kubernetes apt repository
    echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

    # Install the binaries
    sudo apt update
    sudo apt-get install -y kubelet kubeadm kubectl

    echo "Dependencies installed."
}

install_matchbox() {
    wget -P "${TARGET}" https://github.com/poseidon/matchbox/releases/download/v0.10.0/matchbox-v0.10.0-linux-amd64.tar.gz
    tar xzvf "${TARGET}/matchbox-v0.10.0-linux-amd64.tar.gz"

    sudo cp "${TARGET}/matchbox" /usr/local/bin
    sudo cp "${TARGET}/contrib/systemd/matchbox.service" /etc/systemd/system/matchbox.service

    useradd -U matchbox    
}

configure_kea() {
    sudo cp ${ETC_DIR}/kea/* /etc/kea/
}

configure_radvd() {
    sudo cp ${ETC_DIR}/radvd/radvd.conf /etc/radvd.conf
}


configure_containerd() {
    # Generate default configuration
    sudo mkdir -p /etc/containerd
    containerd config default | sudo tee /etc/containerd/config.toml > /dev/null

    # Crucial: Configure containerd to use the systemd cgroup driver
    sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml

    # Restart and enable containerd
    sudo systemctl restart containerd
    sudo systemctl enable containerd

}

configure_kubernetes() {
    sudo swapoff -a
    sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

    cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
    overlay
    br_netfilter
EOF

    # Configure sysctl parameters
    cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
    net.bridge.bridge-nf-call-iptables  = 1
    net.bridge.bridge-nf-call-ip6tables = 1
    net.ipv4.ip_forward                 = 1
EOF

    # Apply sysctl parameters without rebooting
    sudo sysctl --system

    sudo kubeadm init \
        --apiserver-advertise-address=192.168.22.2 \
        --pod-network-cidr=10.10.0.0/16 \
        --cri-socket=unix:///run/containerd/containerd.sock

    mkdir -p $HOME/.kube
    sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
    sudo chown $(id -u):$(id -g) $HOME/.kube/config

    kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/calico.yaml

    kubectl get nodes
    kubectl get pods -n kube-system

    kubeadm token create --print-join-command
        
}

setup() {
    install_matchbox
    configure_kea
    configure_radvd
    configure_containerd
    configure_kubernetes
}

cleanup() {
    echo "cleaning up..."

    delete_network

    echo "clean up is done."
}

main "$@"