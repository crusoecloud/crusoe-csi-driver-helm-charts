#!/usr/bin/env bash
# Upgrade assertions for the chart. Needs a reachable Kubernetes cluster; a kind
# cluster is enough, since nothing here waits for pods to become ready.
#
# Render assertions (hack/test-storageclass-render.sh) check one chart version in
# isolation and cannot see anything about upgrades. These cover the behaviour that
# only appears when a release already exists: whether values stored at install
# time survive, and whether a chart default that changed actually reaches the
# cluster.
#
# The last case asserts a Helm behaviour we do NOT want: `--reuse-values` failing
# to deliver a changed default. It is here so that if Helm ever fixes it, or if
# someone reaches for that flag again, the test says so out loud.
#
# Usage: hack/test-upgrade.sh [chart-dir]
set -euo pipefail

CHART="${1:-charts/crusoe-csi-driver}"
REPO_NAME="${REPO_NAME:-crusoe}"
REPO_URL="${REPO_URL:-https://crusoecloud.github.io/crusoe-csi-driver-helm-charts/charts}"
# Pinned to a published version whose appVersion differs from the local chart's,
# so the image-tag assertions have something to detect. Bump when 0.10.20 ages
# out of the repo; the script fails loudly if the appVersions match.
PREV_VERSION="${PREV_VERSION:-0.10.20}"
NS="${NS:-csi-upgrade-test}"
REL="crusoe-csi-driver"
FAILED=0

pass() { printf '  ok    %s\n' "$1"; }
fail() { printf '  FAIL  %s\n' "$1"; FAILED=1; }
check_eq() {
  local desc="$1" want="$2" got="$3"
  if [[ "$want" == "$got" ]]; then pass "$desc"; else fail "$desc (want '$want', got '$got')"; fi
}

need() { command -v "$1" >/dev/null || { echo "missing required tool: $1" >&2; exit 2; }; }
need helm
need kubectl

if ! kubectl cluster-info --request-timeout=10s >/dev/null 2>&1; then
  echo "no reachable cluster. Create one first, e.g.: kind create cluster" >&2
  exit 2
fi

# The chart creates cluster-scoped CSIDriver objects with fixed names, so the
# cases cannot run side by side in separate namespaces. Install and remove one at
# a time.
cleanup() { helm uninstall "$REL" -n "$NS" >/dev/null 2>&1 || true; }
trap 'cleanup; kubectl delete ns "$NS" --ignore-not-found >/dev/null 2>&1 || true' EXIT

LOCAL_APP="$(helm show chart "$CHART" | awk '/^appVersion:/{gsub(/"/,"",$2); print $2}')"
helm repo add "$REPO_NAME" "$REPO_URL" >/dev/null 2>&1 || true
helm repo update "$REPO_NAME" >/dev/null
PREV_APP="$(helm show chart "$REPO_NAME/$REL" --version "$PREV_VERSION" \
  | awk '/^appVersion:/{gsub(/"/,"",$2); print $2}')"

echo "==> upgrade assertions"
echo "    published $PREV_VERSION (appVersion $PREV_APP) -> local $(helm show chart "$CHART" | awk '/^version:/{print $2}') (appVersion $LOCAL_APP)"

if [[ "$PREV_APP" == "$LOCAL_APP" ]]; then
  echo "  FAIL  PREV_VERSION appVersion matches the local chart, so the image-tag" >&2
  echo "        assertions cannot detect anything. Point PREV_VERSION at a release" >&2
  echo "        whose appVersion differs." >&2
  exit 1
fi

# What image tag does the rendered release actually carry? `helm list` reports the
# chart's appVersion whether or not the workloads moved, so ask the manifest.
driver_image_tags() {
  helm get manifest "$REL" -n "$NS" | grep -oE 'crusoe-csi-driver:v[0-9]+\.[0-9]+\.[0-9]+' | sort -u | tr '\n' ' ' | sed 's/ $//'
}
sc_count() { helm get manifest "$REL" -n "$NS" | grep -c '^kind: StorageClass' || true; }
default_sc() {
  helm get manifest "$REL" -n "$NS" \
    | awk '/^kind: StorageClass/{n=""} /^  name: /{n=$2} /is-default-class/{print n}'
}

install_prev() {
  helm install "$REL" "$REPO_NAME/$REL" --version "$PREV_VERSION" \
    -n "$NS" --create-namespace \
    --set crusoe.projectID=test-project-id >/dev/null
}

# --- Case 1: an existing release must not gain a StorageClass on upgrade -------
# This is the "existing clusters are untouched" guarantee. The release predates
# the storageClasses key entirely, so the chart's new defaults decide, and they
# are off.
cleanup; install_prev
check_eq "before upgrade: no StorageClass" 0 "$(sc_count)"
helm upgrade "$REL" "$CHART" -n "$NS" --reset-then-reuse-values >/dev/null
check_eq "after upgrade: still no StorageClass" 0 "$(sc_count)"
check_eq "values stored at install survived" "test-project-id" \
  "$(helm get values "$REL" -n "$NS" -o json | grep -o 'test-project-id' | head -1)"

# --- Case 2: --reset-then-reuse-values delivers the new image ------------------
check_eq "driver image moved to the new appVersion" "crusoe-csi-driver:$LOCAL_APP" "$(driver_image_tags)"

# --- Case 3: opting in during the upgrade, the way the CMK bootstrap does ------
cleanup; install_prev
helm upgrade "$REL" "$CHART" -n "$NS" --reset-then-reuse-values \
  --set storageClasses.fs.enabled=true \
  --set storageClasses.fs.isDefault=true \
  --set storageClasses.ssd.enabled=true >/dev/null
check_eq "opt-in renders both classes" 2 "$(sc_count)"
check_eq "shared filesystem class is the default" "crusoe-fs" "$(default_sc)"
check_eq "opt-in did not discard stored values" "test-project-id" \
  "$(helm get values "$REL" -n "$NS" -o json | grep -o 'test-project-id' | head -1)"

# --- Case 4: --reuse-values does NOT deliver the new image ---------------------
# Asserting the broken behaviour on purpose. If this ever starts failing, Helm
# changed and the guidance in README/CHANGELOG can be revisited.
cleanup; install_prev
helm upgrade "$REL" "$CHART" -n "$NS" --reuse-values >/dev/null
check_eq "--reuse-values leaves the old image in place" "crusoe-csi-driver:$PREV_APP" "$(driver_image_tags)"
check_eq "--reuse-values still reports the new appVersion" "$LOCAL_APP" \
  "$(helm list -n "$NS" -o json | sed -n 's/.*"app_version":"\([^"]*\)".*/\1/p')"

echo
if [[ "$FAILED" -ne 0 ]]; then
  echo "==> FAILED"
  exit 1
fi
echo "==> all assertions passed"
