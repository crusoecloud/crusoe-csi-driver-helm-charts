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