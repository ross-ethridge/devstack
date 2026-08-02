# Fleet
- Install Rancher Fleet using Helm

## Install the Helm repo for Fleet

```bash
helm repo add fleet https://rancher.github.io/fleet-helm-charts/
```

## Install the Fleet CRD's

```bash
helm -n cattle-fleet-system install --create-namespace --wait fleet-crd fleet/fleet-crd
```

## Install the Fleet controllers

```bash
helm -n cattle-fleet-system install --create-namespace --wait fleet fleet/fleet -f values.yaml
```

### Verify the installation

```bash
kubectl -n cattle-fleet-system logs -l app=fleet-controller

kubectl -n cattle-fleet-system get pods -l app=fleet-controller
```