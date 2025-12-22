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

## Usage

See the [examples](examples) directory for persistent disk and shared filesystem volume examples.

## Feature Matrix

| Feature               | Persistent Disk (SSD) | Shared Filesystem (FS)                                                             |
|-----------------------|-----------------------|------------------------------------------------------------------------------------|
| Access Modes          | ReadWriteOnce         | ReadWriteOnce, ReadWriteMany                                                       |
| Volume Modes          | Block, Filesystem     | Filesystem                                                                         |
| Volume Expansion      | Offline               | Offline, Online                                                                    |
| Instance Type Support | All instance types    | All `c1a` and `s1a` instance types, [full GPU instance types](#full-gpu-instances) |

#### Full GPU Instance Types

Shared Filesystems are generally supported on the largest instance type in a family for GPU enabled instance types. For most GPU instance types, the largest instance type is the `*.8x` type.

For `l40s-48gb` instances, the largest instance type is the `l40s-48gb.10x` type. Shared Filesystems are not supported on `l40s-48gb.8x` types or smaller.

## Non-CMK Deployments

If you are deploying on a self-managed Kubernetes cluster, it is **strongly recommended** that you change the `crusoe.projectID` value to the Crusoe project ID
that contains your node VMs.
