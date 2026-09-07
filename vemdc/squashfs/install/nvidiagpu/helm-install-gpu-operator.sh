helm install --wait gpu-operator \
  -n gpu-operator --create-namespace \
  nvidia/gpu-operator \
  --set driver.enabled=false
