# Install cilium using Helm

## Add the repo

```bash
helm repo add cilium https://helm.cilium.io/

helm repo update
```

## Install Cilium

```bash
helm upgrade --install cilium cilium/cilium --namespace kube-system -f values.yaml
```
