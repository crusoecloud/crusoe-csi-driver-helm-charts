## v0.10.21

* Bump crusoe-csi-driver to `v0.4.12`. The `fs` driver can now resolve the NFS storage endpoint to explicit IPs in userspace and hand them to the mount, instead of relying on in-kernel DNS resolution while the mount is in progress. This removes a class of intermittent NFS mount failures caused by name resolution in the mount path. The behavior is gated by a server-side, per-project flag and is **off by default**, so this upgrade is a no-op until the flag is enabled for a project.

### Upgrade Instructions

* Update repositories: `helm repo update`
* Update chart: `helm upgrade crusoe-csi-driver <repo alias>/crusoe-csi-driver --version 0.10.21 -n crusoe-system --reuse-values`
    * `--reuse-values` preserves the existing driver configuration (project ID, API keys, NFS settings).
* The `fs` node DaemonSet pods restart on upgrade to pick up the new image. Existing NFS mounts live in the kernel and are unaffected; only new mounts use the updated path.
* No topology-label changes — safe in-place upgrade; no node recreation required.

## v0.10.20

* The `fs` node DaemonSet now resolves DNS via the node's resolver (`dnsPolicy: Default`) instead of the in-cluster DNS service. The driver resolves only external names (the storage endpoint and the API endpoint) and does not require in-cluster DNS, so this keeps NFS name resolution on the node's own DNS path. Controlled by `node.fs.dns.useNodeResolver` (default `true`).

### Upgrade Instructions

* Update repositories: `helm repo update`
* Update chart: `helm upgrade crusoe-csi-driver <repo alias>/crusoe-csi-driver --version 0.10.20 -n crusoe-system --reuse-values`
    * `--reuse-values` preserves the existing driver configuration (project ID, API keys, NFS settings).
* The `fs` node DaemonSet pods restart on upgrade to pick up the new DNS policy. Existing NFS mounts live in the kernel and are unaffected; only new mounts use the updated resolution path.
* To opt out and keep using the in-cluster DNS service, set `node.fs.dns.useNodeResolver=false`.

## v0.10.19

* Lowered the `csi-liveness-probe` sidecar log verbosity from `--v=5` to `--v=2` on both the node DaemonSet and the controller Deployment. At `--v=5` the liveness probe logged every health-check round-trip — and because the kubelet liveness/readiness probes hit it on a 2-second period, this produced a very high, continuous volume of routine `"Health check succeeded"` / gRPC-trace lines with no diagnostic value. At `--v=2` successful probes are silent while probe **failures are still logged**. The `/healthz` health-checking behavior and the Prometheus `/metrics` endpoint are unchanged. The other CSI sidecars (`csi-node-driver-registrar`, `csi-attacher`, `csi-provisioner`, `csi-resizer`) intentionally remain at `--v=5`. No driver image change (`appVersion` unchanged).

### Upgrade Instructions

* Update repositories: `helm repo update`
* Update chart: `helm upgrade crusoe-csi-driver <repo alias>/crusoe-csi-driver --version 0.10.19 -n crusoe-system --reuse-values`
    * `--reuse-values` preserves the existing driver configuration (project ID, API keys, NFS settings).
* Safe in-place upgrade — this only lowers sidecar log verbosity. Pods roll normally; there are no topology-label changes and no node recreation required.

## v0.10.18

* Shared filesystems are now supported on **all instance types and slice sizes**, including every L40s slice size (previously limited to full-node slices on GPU instance types). Ships crusoe-csi-driver `v0.4.11`.

### Upgrade Instructions

* Update repositories: `helm repo update`
* Update chart: `helm upgrade crusoe-csi-driver <repo alias>/crusoe-csi-driver --version 0.10.18 -n crusoe-system --reuse-values`
    * `--reuse-values` preserves the existing driver configuration (project ID, API keys, NFS settings).
* **Existing GPU nodes — action required:** this release changes the node topology label `fs.csi.crusoe.ai/supports-shared-disks` to `true` on affected instance types. CSI topology labels are **immutable** once written, so on any node that previously reported `false` the `node-driver-registrar` container will `CrashLoopBackOff` with a `detected topology value collision` error until the stale label is cleared. Resolve per affected node by **either**:
    * recreating the node / node pool — a fresh node registers the correct value cleanly (no manual step), **or**
    * patching the label in place: `kubectl label node <node> fs.csi.crusoe.ai/supports-shared-disks=true --overwrite`
    * Newly-created clusters and nodes are not affected.

## v0.10.12

* Added `NodeGetVolumeStats` support to the CSI driver.
    * The driver now reports filesystem volume usage (bytes and inodes) via `NodeGetVolumeStats`, enabling kubelet to populate volume statistics Prometheus metrics (`kubelet_volume_stats_*`).
    * Block volumes return a healthy `VolumeCondition` with no usage data.
    * The `GET_VOLUME_STATS` node capability is now advertised.
* This resolves an issue where volume metrics were unavailable, preventing monitoring and alerting on disk usage conditions.

### Upgrade Instructions

* To update the chart in the `crusoe-system` namespace:
    * Update repositories: `helm repo update`
    * Update chart: `helm upgrade crusoe-csi-driver <repo alias>/crusoe-csi-driver --version v0.10.12 -n crusoe-system`

## v0.10.4
* Fixed a bug where read-only mounts of shared volumes could fail on virtiofs due to the `noload` mount option being passed.

### Upgrade Caveats

* These instructions are applicable for upgrades from any version prior to v0.10.4 to v0.10.4.
* CSI node pods will restart with the updated driver.
* Existing volumes and mounts will not be affected by the upgrade.

### Upgrade Instructions

* To update the chart in the `crusoe-system` namespace:
    * Update repositories: `helm repo update`
    * Update chart: `helm upgrade crusoe-csi-driver <repo alias>/crusoe-csi-driver --version v0.10.4 -n crusoe-system`

## v0.10.3

* Enhanced NFS driver checks to detect and automatically fix broken installations.
    * CSI init container now validates NFS driver functionality before mounting volumes.
* Health checks run on every pod restart to ensure NFS reliability.

### Upgrade Caveats

* These instructions are applicable for upgrades from any version prior to v0.10.3 to v0.10.3.
    * If upgrading from a version prior to v0.7.0, please follow the upgrade instructions for v0.7.0 first.
* CSI node pods will restart with the updated init container script.
* Existing volumes and mounts will not be affected by the upgrade.
* Nodes with broken NFS installations will automatically remediate on pod restart.

### Upgrade Instructions

* To update the chart in the `crusoe-system` namespace:
    * Update repositories: `helm repo update`
    * Update chart: `helm upgrade crusoe-csi-driver <repo alias>/crusoe-csi-driver --version v0.10.3 -n crusoe-system`

## v0.10.2

* Added support for NFS driver pre-installed in worker images for faster node startup.
    * CSI init container automatically detects pre-installed NFS drivers and skips redundant installation.
    * Significantly reduces node initialization time when using NFS-enabled worker images.

### Upgrade Caveats

* These instructions are applicable for upgrades from any version prior to v0.10.2 to v0.10.2.
    * If upgrading from a version prior to v0.7.0, please follow the upgrade instructions for v0.7.0 first.
* Volume creation, attachment, detachment, and deletion may be momentarily delayed while the Crusoe CSI Driver is being updated.
* Existing volumes managed by CSI will not be deleted or modified by the upgrade.
* Volumes already successfully mounted by pods will not be affected by the upgrade.

### Upgrade Instructions

* To update the chart in the `crusoe-system` namespace:
    * Update repositories: `helm repo update`
    * Update chart: `helm upgrade crusoe-csi-driver <repo alias>/crusoe-csi-driver --version v0.10.2 -n crusoe-system`

## v0.10.0

* NFS mounting support has been enabled for the `fs` driver.
    * If NFS support is enabled for the Crusoe project, shared volumes will be mounted using NFS instead of virtiofs by default.
        * Existing shared volumes that use virtiofs will continue to function.
    * If NFS support is not enabled for the Crusoe project, shared volumes will continue to mount using virtiofs.

### Upgrade Caveats

* These instructions are applicable for upgrades from any version prior to v0.10.0 to v0.10.0.
    * If upgrading from a version prior to v0.7.0, please follow the upgrade instructions for v0.7.0 first.
* Volume creation, attachment, detachment, and deletion may be momentarily delayed while the Crusoe CSI Driver is being updated.
* Existing volumes managed by CSI will not be deleted or modified by the upgrade
    * However, they will mount using NFS if NFS support is enabled for the Crusoe project.
* Volumes already successfully mounted by pods will not be affected by the upgrade

### Upgrade Instructions

* To update the chart in the `crusoe-csi-driver` namespace:
    * Update repositories: `helm repo update`
    * Update chart: `helm upgrade <chart alias> <repo alias>/crusoe-csi-driver --version v0.10.0 -n crusoe-csi-driver`


## v0.9.0

* Fixes an issue where brief storage disruptions could prevent volumes from being mounted.

### Upgrade Caveats

* These instructions are applicable for upgrades from any version prior to v0.9.0 to v0.9.0.
  * If upgrading from a version prior to v0.7.0, please follow the upgrade instructions for v0.7.0 first.
* Volume creation, attachment, detachment, and deletion may be momentarily delayed while the Crusoe CSI Driver is being updated.
* Existing volumes managed by CSI will not be deleted or modified by the upgrade
* Volumes already successfully mounted by pods will not be affected by the upgrade

### Upgrade Instructions

* To update the chart in the `crusoe-csi-driver` namespace:
  * Update repositories: `helm repo update`
  * Update chart: `helm upgrade <chart alias> <repo alias>/crusoe-csi-driver --version v0.9.0 -n crusoe-csi-driver`

## v0.8.0

* Fixed an issue where the CSI driver could get stuck in a retry loop when mounting a volume to a directory that already had a volume mounted to it.

### Breaking Changes

* N/A

### Upgrade Caveats

* These instructions are applicable for upgrades from any version prior to v0.8.0 to v0.8.0.
* Volume creation, attachment, detachment, and deletion may be momentarily delayed while the Crusoe CSI Driver is being updated.
* Existing volumes managed by CSI will not be deleted or modified by the upgrade
* Volumes already successfully mounted by pods will not be disrupted by the upgrade

### Upgrade Instructions

* To update the chart in the `crusoe-csi-driver` namespace:
  * Update repositories: `helm repo update`
  * Update chart: `helm upgrade <chart alias> <repo alias>/crusoe-csi-driver --version v0.8.0 -n crusoe-csi-driver`

## v0.7.0

### Breaking Changes

* The default `crusoe.secrets.crusoeApiKeys.accessKeyPath` and `crusoe.secrets.crusoeApiKeys.secretKeyPath` have changed to `CRUSOE_ACCESS_KEY` and `CRUSOE_SECRET_KEY` respectively.
  * Users who wish to maintain the old behavior should explicitly set both `crusoe.secrets.crusoeApiKeys.accessKeyPath` and `crusoe.secrets.crusoeApiKeys.secretKeyPath` to `CRUSOE_CSI_ACCESS_KEY` and `CRUSOE_CSI_SECRET_KEY` respectively in a custom `values.yaml`.


### Upgrade Caveats

* These instructions are applicable for upgrades from any version prior to v0.7.0 to v0.7.0.
* Volume creation, attachment, detachment, and deletion may be momentarily delayed while the Crusoe CSI Driver is being updated.
* Existing volumes managed by CSI will not be deleted or modified by the upgrade
* Volumes already successfully mounted by pods will not be disrupted by the upgrade

### Upgrade Instructions

* To update the chart in the `crusoe-csi-driver` namespace:
  * Update repositories: `helm repo update`
  * Update chart: `helm upgrade <chart alias> <repo alias>/crusoe-csi-driver --version v0.7.0 -n crusoe-csi-driver`