## Crusoe Container Storage Interface (CSI) Helm Charts

This repository defines the official Container Storage Interface (CSI) Helm Charts for use with [Crusoe Cloud](https://crusoecloud.com/), 
the world's first carbon-reducing, low-cost GPU cloud platform.

**The CSI Helm Charts are currently in :construction: Alpha :construction:.**

## Support

**The Crusoe CSI Driver is only supported on Crusoe Managed Kubernetes (CMK).** 
This guide assumes that the user has already set up CMK on Crusoe Cloud.

Other configurations will be supported on a best-effort basis.

## Prerequisites

### Setting up credentials

As the CSI Driver will communicate with the Crusoe Cloud API to orchestrate storage operations, you will have to set up
credentials in your Kubernetes cluster which the driver can then use to communicate with the API. Here is a template `.yaml` file
which can be modified with your credentials and applied to your cluster. The examples below assume the intended namespace
for the CSI Driver is `crusoe-csi-driver`.

```yaml
apiVersion: v1
data:
  CRUSOE_CSI_ACCESS_KEY: <base-64 encoded Crusoe Access Key>
  CRUSOE_CSI_SECRET_KEY: <base-64 encoded Crusoe Secret Key>
kind: Secret
metadata:
  name: crusoe-api-keys
  namespace: crusoe-csi-driver

```

An appropriate secret can be created in your cluster by filling out the command below and running it in the terminal:
```shell
kubectl create secret generic crusoe-api-keys -n crusoe-csi-driver -o yaml \
--from-literal=CRUSOE_CSI_ACCESS_KEY=$YOUR_CRUSOE_ACCESS_KEY \
--from-literal=CRUSOE_CSI_SECRET_KEY=$YOUR_CRUSOE_SECRET_KEY
```

By default, the driver will use the `crusoe-api-keys` secret.
The name of the secret may be changed in the `secrets` section of the `values.yaml` file.

### Helm

[Helm](https://helm.sh) must be installed to use the charts.  Please refer to
Helm's [documentation](https://helm.sh/docs) to get started.

Once Helm has been set up correctly, add the repo as follows:

helm repo add <repo alias> https://crusoecloud.github.io/crusoe-csi-driver-helm-charts

If you have already added this repo earlier, run `helm repo update` to retrieve
the latest versions of the packages.  You can then run `helm search repo
<repo alias>` to see the available charts.

## Installation


To install the Crusoe CSI Driver chart:

    helm install <chart alias> <repo alias>/crusoe-csi-driver-helm-charts

To uninstall the chart:

    helm delete <chart alias>

## Customization

The name of the secret containing the access and secret keys can be changed by modifying the `secrets.crusoeApiKeys.secretName` value.

## Non-CMK Deployments

If you are deploying on a self-managed Kubernetes cluster, it is **strongly recommended** that you change the `crusoe.projectID` value to the Crusoe project ID
that contains your node VMs.
