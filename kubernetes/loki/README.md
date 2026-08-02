# Loki

Distributed-mode Loki (`deploymentMode: Distributed`, the `grafana/loki`
chart's microservices mode - not the deprecated `loki-distributed` chart),
deployed via Fleet as a Helm chart, storing chunks in MinIO.

## What's here

`fleet.yaml` points Fleet at the `grafana/loki` Helm chart and applies
`values.yaml` on top. No raw manifests - Fleet installs the chart directly.

## One-time: MinIO credentials

Loki reads S3 credentials from a `loki-credentials` Secret that is **not**
stored in git, same pattern as `minio-credentials`
(see `../minio/README.md`):

```bash
kubectl create namespace loki
kubectl create secret generic loki-credentials -n loki \
  --from-literal=ACCESS_KEY_ID=<key> \
  --from-literal=SECRET_ACCESS_KEY=<secret>
```

`values.yaml` never contains the literal values - `loki.storage.s3.accessKeyId`/
`secretAccessKey` are set to `${ACCESS_KEY_ID}`/`${SECRET_ACCESS_KEY}`,
resolved at Loki startup by `-config.expand-env=true`
(`global.extraArgs`) against env vars injected from the Secret
(`global.extraEnvFrom`). This is Loki's own documented mechanism for
keeping secrets out of config, not a repo-specific hack:
https://grafana.com/docs/loki/latest/configure/#use-environment-variables-in-the-configuration

`fleet.yaml` sets `helm.disablePreProcess: true` - Fleet Go-templates values
files using `${}` delimiters (to avoid colliding with Helm's `{{ }}`) and
would otherwise try to resolve `${ACCESS_KEY_ID}` itself before Loki ever
sees it, failing the bundle with `function "ACCESS_KEY_ID" not defined`.

## One-time: MinIO buckets

Loki doesn't create its object storage buckets - they must exist before
the pods come up:

```bash
kubectl run mc --rm -i --restart=Never -n loki --image=quay.io/minio/mc \
  --overrides='{"spec":{"containers":[{"name":"mc","image":"quay.io/minio/mc","command":["sh","-c","mc alias set minio http://minio.minio.svc.cluster.local:9000 \"$ACCESS_KEY_ID\" \"$SECRET_ACCESS_KEY\" && mc mb minio/chunks minio/ruler"],"envFrom":[{"secretRef":{"name":"loki-credentials"}}]}]}}' \
  -- true
```

Bucket names must match `loki.storage.bucketNames` in `values.yaml`
(`chunks`, `ruler`).

## Deploy via Fleet

Added to the `devstack-deployments` GitRepo (`../fleet/deployments.yaml`).
Create the namespace/Secret/buckets above *before* pushing, or the pods
will crash-loop until they exist. Verify:

```bash
kubectl get bundle -n fleet-local | grep loki
kubectl -n loki get pods
```

## Reaching it

Loki has no UI of its own - query it through Grafana as a data source
(LogQL via the Explore view), same as Tempo for traces.

In-cluster URL for the Grafana data source: `http://loki-gateway.loki.svc.cluster.local`
(port 80, routed to the gateway's actual listen port 8080 by the Service).

To hit it directly (e.g. `curl`, testing), forward the **Service**, not a
pod - pods listen on 8080 internally, so forwarding a pod on port 80 gets
connection refused:

```bash
kubectl -n loki port-forward svc/loki-gateway 8080:80
```
