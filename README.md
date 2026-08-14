## Crusoe Container Storage Interface (CSI) Helm Charts

This repository defines the official Container Storage Interface (CSI) Helm Charts for use with [Crusoe Cloud](https://crusoecloud.com/).

**The CSI Helm Charts are currently in :construction: Alpha :construction:.**

## Support

**The Crusoe CSI Driver is only supported on Crusoe Managed Kubernetes (CMK).** 
This guide assumes that the user has already set up CMK on Crusoe Cloud.

Other configurations will be supported on a best-effort basis.

## Changelog

Please refer to the [CHANGELOG](CHANGELOG.md) for breaking changes and upgrade instructions.

## Prerequisites

The examples below assume the intended namespace
for the CSI Driver is `crusoe-system`.

### Setting up credentials

As the CSI Driver will communicate with the Crusoe Cloud API to orchestrate storage operations, you will have to set up
credentials in your Kubernetes cluster which the driver can then use to communicate with the API. You can generate an appropriate
Crusoe API key pair in the Security → Tokens tab of the Cruosoe Cloud UI.

Here is a template `.yaml` file which can be modified with your credentials and applied to your cluster.

```yaml
apiVersion: v1
data:
  CRUSOE_ACCESS_KEY: <base-64 encoded Crusoe Access Key>
  CRUSOE_SECRET_KEY: <base-64 encoded Crusoe Secret Key>
kind: Secret
metadata:
  name: crusoe-api-keys
  namespace: crusoe-system

```

An appropriate secret can be created in your cluster by filling out the command below and running it in the terminal:
```shell
kubectl create secret generic crusoe-api-keys -n crusoe-system -o yaml \
--from-literal=CRUSOE_ACCESS_KEY=$YOUR_CRUSOE_ACCESS_KEY \
--from-literal=CRUSOE_SECRET_KEY=$YOUR_CRUSOE_SECRET_KEY
```

By default, the driver will use the `crusoe-api-keys` secret.
The name of the secret as well as the name of the Secret keys that contain the access and secret keys
may be changed in the `secrets` section of the `values.yaml` file.

### Helm

[Helm](https://helm.sh) must be installed to use the charts.  Please refer to
Helm's [documentation](https://helm.sh/docs) to get started.

Once Helm has been set up correctly, add the repo as follows:

    helm repo add <repo alias> https://crusoecloud.github.io/crusoe-csi-driver-helm-charts/charts

If you have already added this repo earlier, run `helm repo update` to retrieve
the latest versions of the packages.  You can then run `helm search repo
<repo alias>` to see the available charts.

## Installation


To install the Crusoe CSI Driver chart in the `crusoe-system` namespace:

    helm install <chart alias> <repo alias>/crusoe-csi-driver -n crusoe-system

To uninstall the chart:

    helm delete <chart alias>

## Customization

The name of the secret containing the access and secret keys can be changed by modifying the `secrets.crusoeApiKeys.secretName` value.

The persistent disk and shared filesystem drivers operate independently, and can be enabled or disabled by modifying the `csi.ssd.enabled` and `csi.fs.enabled` values.

## StorageClasses

The chart can create a StorageClass for each driver. **Both are off by default**, so installing or
upgrading the chart never creates a StorageClass you did not ask for, and never changes which class a
PersistentVolumeClaim without a `storageClassName` binds against. Clusters that manage their own
StorageClasses are unaffected.

| value | default | description |
|---|---|---|
| `storageClasses.<type>.enabled` | `false` | Create the StorageClass. Requires `csi.<type>.enabled` to also be true. |
| `storageClasses.<type>.isDefault` | `false` | Annotate the class `storageclass.kubernetes.io/is-default-class`, so a PVC that omits `storageClassName` uses it. |
| `storageClasses.<type>.name` | `crusoe-ssd` / `crusoe-fs` | The StorageClass name. |
| `storageClasses.<type>.reclaimPolicy` | `Delete` | |
| `storageClasses.<type>.volumeBindingMode` | `WaitForFirstConsumer` | Provisioning waits until a Pod is scheduled, so the volume is placed in the right location. |
| `storageClasses.<type>.allowVolumeExpansion` | `true` | |
| `storageClasses.<type>.parameters` | `{}` | No parameters are supported yet. Present for forward compatibility. |
| `storageClasses.<type>.mountOptions` | `[]` | Extra `mount(8)` options, e.g. `["noac"]` to disable NFS attribute caching. Applied before the driver's own mandatory options, so a conflicting key (`fs` only: `vers`, `nconnect`, `spread_reads`, `spread_writes`) is overridden by the driver's value. Most StorageClass fields are immutable once created — see below. |

To create both classes and make the shared filesystem the cluster default:

```shell
helm upgrade <chart alias> <repo alias>/crusoe-csi-driver -n crusoe-system \
  --reset-then-reuse-values \
  --set storageClasses.ssd.enabled=true \
  --set storageClasses.fs.enabled=true \
  --set storageClasses.fs.isDefault=true
```

To make the persistent disk class the default instead, set `storageClasses.ssd.isDefault=true` and
leave `storageClasses.fs.isDefault` false.

`--reset-then-reuse-values` needs Helm 3.14 or later. Prefer it over `--reuse-values`: both keep the
values your release was installed with, and a bare `helm upgrade` would drop them, but
`--reuse-values` also carries the previous chart's defaults forward, so a default that changed in the
new chart never takes effect. On older Helm, save and re-supply the values instead:

```shell
helm get values <chart alias> -n crusoe-system > values.yaml   # no --all
helm upgrade <chart alias> <repo alias>/crusoe-csi-driver -n crusoe-system \
  -f values.yaml --set storageClasses.fs.enabled=true --set storageClasses.fs.isDefault=true
```

Things to know before enabling:

* **Set `isDefault` on at most one class.** Kubernetes tolerates more than one default, but which one
  wins is not worth relying on. If the cluster already has a default from another provisioner, adding a
  second can change where existing PVCs provision.
* **`crusoe-fs` provisions at a 1 TiB minimum, in whole-terabyte increments.** A PVC asking for less, or
  for a size that is not a whole number of TiB, is rejected. Use `crusoe-ssd` for smaller volumes. This
  matters most when `crusoe-fs` is the cluster default, because every PVC that omits `storageClassName`
  then has to satisfy it.
* **The default class names differ from the ones in [examples](examples)** (`crusoe-csi-driver-ssd-sc`,
  `crusoe-csi-driver-fs-sc`), so enabling these does not collide with an example applied by hand. Helm
  will not adopt an object it does not own: if a class of the same name already exists outside the
  release, rename via `storageClasses.<type>.name` or delete the existing object first.
* **Change the default through values, not by editing the object.** Once the chart creates a
  StorageClass, Helm owns it, and a later `helm upgrade` restores it to what the chart renders. An
  annotation removed with `kubectl edit` comes back.
* **Most StorageClass fields are immutable once created.** To change `reclaimPolicy`,
  `volumeBindingMode`, `parameters`, or `mountOptions` later, delete the class and let the next upgrade
  recreate it. Existing PersistentVolumes keep the settings they were created with.

## Usage

See the [examples](examples) directory for persistent disk and shared filesystem volume examples.

## Feature Matrix

| Feature               | Persistent Disk (SSD) | Shared Filesystem (FS)       |
|-----------------------|-----------------------|------------------------------|
| Access Modes          | ReadWriteOnce         | ReadWriteOnce, ReadWriteMany |
| Volume Modes          | Block, Filesystem     | Filesystem                   |
| Volume Expansion      | Offline               | Offline, Online              |
| Instance Type Support | All instance types    | All instance types           |
| Minimum Volume Size   | 1 GiB                 | 1 TiB                        |
| Volume Size Increment | 1 GiB                 | 1 TiB                        |

Shared Filesystems are supported on every instance type and every slice count. Earlier driver versions
restricted them to full-node GPU instance types; that restriction was removed in driver `v0.4.11`
(chart `0.10.18`).

Shared Filesystem volumes are provisioned in whole terabytes, with a minimum of 1 TiB. A PVC that
requests less than 1 TiB, or a size that is not a whole number of TiB, is rejected. Use a persistent
disk volume for anything smaller.

## Non-CMK Deployments

If you are deploying on a self-managed Kubernetes cluster, it is **strongly recommended** that you change the `crusoe.projectID` value to the Crusoe project ID
that contains your node VMs.
