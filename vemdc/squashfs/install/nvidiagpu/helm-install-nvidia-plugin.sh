#!/usr/bin/env bash

cat <<EOF | kubectl apply -f -
apiVersion: node.k8s.io/v1
kind: RuntimeClass
metadata:
  name: nvidia
handler: nvidia
EOF

# helm repo add nvidia-k8s-device-plugin https://nvidia.github.io/k8s-device-plugin
# helm repo update

helm install nvidia-device-plugin nvidia-k8s-device-plugin/nvidia-device-plugin \
  --namespace nvidia-device-plugin --create-namespace \
  --set runtimeClassName=nvidia

#kubectl label node <your-node-name> nvidia.com/gpu.present=true --overwrite