# MCP Servers

Kubernetes MCP servers deployed as Deployments via kustomize, applied to the
cluster by Fleet (GitOps) instead of `kubectl apply` directly.

## What's here

| Server | Image | Transport | Path |
|---|---|---|---|
| mcp-kubernetes | `mcp/kubernetes` | streamable-http | `/mcp` |
| mcp-kubectl | `mcp/kubectl-mcp-server` | streamable-http | `/mcp` |
| mcp-playwright | `mcp/playwright` | streamable-http | `/mcp` |

All run in the `mcp-servers` namespace (`namespace.yaml`). `mcp-kubernetes`
and `mcp-kubectl` run under a shared `mcp-cluster-admin` ServiceAccount bound
to the built-in `cluster-admin` ClusterRole (`rbac.yaml`) so they can manage
the cluster they're running in.

`mcp/filesystem` was deliberately left out: Claude Code already has native
file tools, and that image only speaks stdio (no `--port`/SSE flag), so it
can't be exposed through the Ingress like the others anyway.

## Deploy via Fleet

One-time: register the GitRepo so Fleet watches this path:

```bash
export GH_TOKEN=<your_github_pat>
cat ../fleet/mcps-repo.yaml | envsubst | kubectl apply -f -
```

Fleet auto-detects the `kustomization.yaml` in this directory and applies it
to the local cluster (the `GitRepo` lives in the `fleet-local` namespace,
which Fleet always targets at the local cluster). Verify:

```bash
kubectl get gitrepo -n fleet-local
kubectl get pods -n mcp-servers
```

Every push to `main` that touches `kubernetes/mcps/` gets picked up
automatically from there on — no more manual `kubectl apply`.

## Reaching the servers

Rancher Desktop's k3s already ships Traefik as a LoadBalancer Service, and
forwards its ports 80/443 to `localhost` on the host. `ingress.yaml` routes
through that same Traefik using one shared prefix-stripped path per server,
so no port-forwarding or extra LoadBalancer Services are needed:

- `http://localhost/mcp-kubernetes/mcp`
- `http://localhost/mcp-kubectl/mcp`
- `http://localhost/mcp-playwright/mcp`

## Add to Claude Code

```bash
claude mcp add --transport http mcp-kubernetes http://localhost/mcp-kubernetes/mcp
claude mcp add --transport http mcp-kubectl http://localhost/mcp-kubectl/mcp
claude mcp add --transport http mcp-playwright http://localhost/mcp-playwright/mcp
```

## Gotchas hit building this

- `mcp/kubernetes` binds to `HOST` env var, defaulting to `localhost` if
  unset — silently unreachable from outside its own container until set to
  `0.0.0.0` (`kubernetes.yaml`).
- `mcp/kubernetes` also supports the older two-endpoint SSE transport
  (`ENABLE_UNSAFE_SSE_TRANSPORT`), which is what this was originally deployed
  with. That transport tells clients to POST follow-up requests to a
  hardcoded, un-prefixed `/messages` path, which breaks under prefix-based
  routing like this Ingress (the client ends up requesting
  `http://localhost/messages` with no `/mcp-kubernetes` prefix -> 404).
  Switched to `ENABLE_UNSAFE_STREAMABLE_HTTP_TRANSPORT` instead, which uses a
  single `/mcp` endpoint like the other two servers and has no such issue.
- `mcp/playwright` rejects requests whose `Host` header doesn't match its
  bind address by default; needs `--allowed-hosts '*'` to accept traffic
  through the Ingress/port-forward (`playwright.yaml`).
- The `mcp-cluster-admin` ClusterRoleBinding is broad by design for a
  personal dev cluster — narrow it if this cluster ever has untrusted
  clients on it.
