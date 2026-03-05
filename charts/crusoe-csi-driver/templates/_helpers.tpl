{{/*
Expand the name of the chart.
*/}}
{{- define "crusoe-csi-driver.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "crusoe-csi-driver.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "crusoe-csi-driver.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "crusoe-csi-driver.labels" -}}
helm.sh/chart: {{ include "crusoe-csi-driver.chart" . }}
{{ include "crusoe-csi-driver.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "crusoe-csi-driver.selectorLabels" -}}
app.kubernetes.io/name: {{ include "crusoe-csi-driver.name" . }}
app.kubernetes.io/instance: {{ include "crusoe-csi-driver.fullname" . }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "crusoe-csi-driver.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "crusoe-csi-driver.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Render the HTTP_PROXY / HTTPS_PROXY / NO_PROXY env vars for the crusoe-csi-driver container.
Called with $.Values.crusoe as context so proxy settings are available at .proxy.*.
NO_PROXY entries are auto-discovered where possible:
  - Pod CIDR: from cilium-config ConfigMap (cluster-pool-ipv4-cidr), falls back to 10.0.0.0/8
  - Kubernetes API ClusterIP: from the kubernetes.default Service
Usage: include "crusoe-csi-driver.proxy-env" $.Values.crusoe | nindent <N>
*/}}
{{- define "crusoe-csi-driver.proxy-env" -}}
{{- if .proxy.enabled }}
{{- $podCIDR := .proxy.noProxy.podCIDR }}
{{- if not $podCIDR }}
{{- $ciliumCM := lookup "v1" "ConfigMap" "kube-system" "cilium-config" }}
{{- if and $ciliumCM $ciliumCM.data (index $ciliumCM.data "cluster-pool-ipv4-cidr") }}
{{- $podCIDR = index $ciliumCM.data "cluster-pool-ipv4-cidr" }}
{{- else }}
{{- $podCIDR = "10.0.0.0/8" }}
{{- end }}
{{- end }}
{{- $k8sClusterIP := "" }}
{{- $k8sSvc := lookup "v1" "Service" "default" "kubernetes" }}
{{- if and $k8sSvc $k8sSvc.spec (index $k8sSvc.spec "clusterIP") }}
{{- $k8sClusterIP = index $k8sSvc.spec "clusterIP" }}
{{- end }}
- name: HTTP_PROXY
  value: {{ printf "%s://%s:%v" .proxy.scheme .proxy.host .proxy.port | quote }}
- name: HTTPS_PROXY
  value: {{ printf "%s://%s:%v" .proxy.scheme .proxy.host .proxy.port | quote }}
- name: NO_PROXY
  value: {{ list "169.254.169.254" "metadata.google.internal" "localhost" "127.0.0.1" $podCIDR $k8sClusterIP .proxy.noProxy.vpcCIDR ".svc.cluster.local" ".cluster.local" | compact | join "," | quote }}
{{- end }}
{{- end -}}

{{/*
Render a container image reference.
Resolution order:
  1. global.imageRegistry  — redirects all images to a single private registry
  2. per-image registry    — the registry field on the individual image (e.g., ghcr.io)
  3. no registry           — image name only (e.g., Docker Hub default)
Usage: include "crusoe-csi-driver.image" (dict "global" $.Values.global "registry" "ghcr.io" "repository" "org/name" "tag" "v1.0.0")
*/}}
{{- define "crusoe-csi-driver.image" -}}
{{- $registry := .global.imageRegistry | default .registry -}}
{{- if $registry -}}
{{- printf "%s/%s:%s" $registry .repository .tag -}}
{{- else -}}
{{- printf "%s:%s" .repository .tag -}}
{{- end -}}
{{- end -}}
