# MinIO

Standalone MinIO deployed via kustomize, applied to the cluster by Fleet
(GitOps), replacing the `docker/minio/compose.yaml` container.

## What's here

Namespace `minio`, a single-replica `Deployment` + `PersistentVolumeClaim`
(`local-path-expandable`, 100Gi) + `Service` exposing the S3 API (9000) and
console (9001).

## One-time: root credentials

The Deployment reads `MINIO_ROOT_USER`/`MINIO_ROOT_PASSWORD` from a
`minio-credentials` Secret that is **not** stored in git (this repo's
`.gitignore` blocks `*secrets.yaml`, and this isn't even that — it's created
directly with `kubectl`, same pattern as the Fleet `GH_TOKEN` in
`../fleet/deployments.yaml`):

```bash
kubectl create namespace minio
kubectl create secret generic minio-credentials -n minio \
  --from-literal=MINIO_ROOT_USER=<user> \
  --from-literal=MINIO_ROOT_PASSWORD=<password>
```

Do this before (or right after) Fleet syncs — the Deployment will crash-loop
until the secret exists.

## Deploy via Fleet

This path was added to the existing `devstack-deployments` GitRepo
(`../fleet/deployments.yaml`), so no new GitRepo registration is needed — if
that GitRepo is already applied, Fleet picks up `kubernetes/minio/`
automatically. Verify:

```bash
kubectl get gitrepo -n fleet-local
kubectl -n minio get pods
```

## Expanding the volume

Bumping `pvc.yaml`'s `resources.requests.storage` and letting Fleet sync it
is **not enough** — the PVC will sit at `ExternalExpanding` ("waiting for an
external controller to expand this PVC") forever. `rancher.io/local-path`
doesn't implement volume expansion at all; `allowVolumeExpansion: true` on
the StorageClass just lets the API server accept the resize request, with
nothing to actually act on it.

This is harmless to work around: the PV is a bare `hostPath` directory with
no quota enforcement, so the requested size is pure bookkeeping — the
directory already has access to whatever free space the node's disk has.
After bumping the size in git (and letting Fleet apply it, or applying
directly), manually patch the PV and PVC status to match:

```bash
PV=$(kubectl get pvc minio-data -n minio -o jsonpath='{.spec.volumeName}')
kubectl patch pv "$PV" -p '{"spec":{"capacity":{"storage":"100Gi"}}}'
kubectl patch pvc minio-data -n minio --subresource=status \
  -p '{"status":{"capacity":{"storage":"100Gi"}}}'
```

`kubectl -n minio describe pvc minio-data` should then show the new
`Capacity` with no more `ExternalExpanding` event.

## Reaching it

Routed through the same Traefik that Rancher Desktop's k3s already runs as a
LoadBalancer on 80/443 (`ingress.yaml`), via host-based rules rather than the
mcps' `stripPrefix` pattern: MinIO's S3 API signs requests over the request
path (SigV4), so stripping a path prefix would break signature verification.
Host-based routing needs no path rewriting.

- Console: http://minio-console.localhost
- API: http://minio-api.localhost

`*.localhost` resolves to 127.0.0.1 without any `/etc/hosts` entry on
Linux/macOS.
