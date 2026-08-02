# Bootstrap

Rebuild the dev cluster from scratch, in order. Each step depends on the one before it.

## 1. Rancher Desktop

Download and install from https://github.com/rancher-sandbox/rancher-desktop/releases,
then disable the built-in Flannel CNI (it's being replaced by Cilium in the
next step): Preferences → Kubernetes → uncheck the flannel/CNI option, then
restart Rancher Desktop.

## 2. Cilium (CNI)

```bash
helm repo add cilium https://helm.cilium.io/
helm repo update
helm upgrade --install cilium cilium/cilium --namespace kube-system -f kubernetes/cilium/values.yaml
```

See `kubernetes/cilium/README.md`.

## 3. Storage class

```bash
kubectl apply -f kubernetes/storage/local-path-expandable.yaml
```

Adds an expandable copy of the built-in `local-path` StorageClass and makes it
the default (`local-path` itself is owned by k3s and reverts edits on node
restart — see comments in the file for why this is a separate object instead
of a patch).

## 4. Fleet (GitOps controller)

```bash
helm repo add fleet https://rancher.github.io/fleet-helm-charts/
helm -n cattle-fleet-system install --create-namespace --wait fleet-crd fleet/fleet-crd
helm -n cattle-fleet-system install --create-namespace --wait fleet fleet/fleet -f kubernetes/fleet/values.yaml
```

Verify:

```bash
kubectl -n cattle-fleet-system get pods -l app=fleet-controller
kubectl -n cattle-fleet-system logs -l app=fleet-controller
```

See `kubernetes/fleet/README.md`.

## 5. MCP servers + MinIO (via Fleet)

One-time GitRepo registration so Fleet watches `kubernetes/mcps/` and
`kubernetes/minio/`:

```bash
export GH_TOKEN=<your_github_pat>
cat kubernetes/fleet/deployments.yaml | envsubst | kubectl apply -f -
```

Fleet auto-applies both kustomizations from there on — every push to `main`
touching either path rolls out automatically, no manual `kubectl apply`.

MinIO also needs a one-time credentials Secret (not stored in git) before
Fleet's Deployment will come up healthy — see `kubernetes/minio/README.md`.

Verify:

```bash
kubectl get gitrepo -n fleet-local
kubectl get pods -n mcp-servers
kubectl get pods -n minio
```

See `kubernetes/mcps/README.md` (includes gotchas around transport/host binding
for each server) and `kubernetes/minio/README.md`.

## 6. Register the MCPs with Claude Code

```bash
claude mcp add --transport http mcp-kubernetes http://localhost/mcp-kubernetes/mcp
claude mcp add --transport http mcp-kubectl http://localhost/mcp-kubectl/mcp
claude mcp add --transport http mcp-playwright http://localhost/mcp-playwright/mcp
```

Rancher Desktop's k3s ships Traefik as a LoadBalancer forwarding 80/443 to
`localhost`, so these routes work without port-forwarding.

## Sanity check

```bash
kubectl get nodes
kubectl -n kube-system get pods -l k8s-app=cilium
kubectl get storageclass
kubectl -n cattle-fleet-system get pods
kubectl -n mcp-servers get pods
claude mcp list
```
