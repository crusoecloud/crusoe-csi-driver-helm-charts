#!/usr/bin/env bash
# Render assertions for the node DaemonSet environment.
#
# The driver reads its flags from the environment through viper, which maps a
# flag name to an env var by upper-casing it and replacing "-" with "_". An env
# var with any other name is silently ignored. The chart used to set NFS_IP from
# crusoe.nfs.ip, which no driver version read, so that value was removed.
#
# Usage: hack/test-node-env-render.sh [chart-dir]
set -euo pipefail

CHART="${1:-charts/crusoe-csi-driver}"
FAILED=0

pass() { printf '  ok    %s\n' "$1"; }
fail() { printf '  FAIL  %s\n' "$1"; FAILED=1; }

render() { helm template t "$CHART" --show-only templates/daemonsets/node.yaml "$@"; }

# Distinct values rendered for one env var, across every node DaemonSet.
env_values() {
  local name="$1"; shift
  render "$@" | grep -A1 -- "- name: $name\$" | awk '$1=="value:" {print $2}' | sort -u | tr '\n' ' ' | sed 's/ $//'
}

check_eq() {
  local desc="$1" want="$2" got="$3"
  if [[ "$want" == "$got" ]]; then pass "$desc"; else fail "$desc (want '$want', got '$got')"; fi
}

echo "==> node env render assertions ($CHART)"

# 1. No NFS host env var by default. The driver uses its own --nfs-host default.
check_eq "no NFS_IP or NFS_HOST by default" 0 \
  "$(render | grep -c -E -- '- name: NFS_(IP|HOST)$' || true)"

# 2. A values file that still sets crusoe.nfs.ip renders, and the value is ignored.
check_eq "leftover crusoe.nfs.ip renders no NFS env var" 0 \
  "$(render --set crusoe.nfs.ip=10.0.0.9 | grep -c -E -- '- name: NFS_(IP|HOST)$' || true)"

# 3. Remote ports keep rendering under the name the driver reads.
check_eq "crusoe.nfs.remotePorts renders as NFS_REMOTE_PORTS" '"100.64.0.2-100.64.0.17"' \
  "$(env_values NFS_REMOTE_PORTS)"
check_eq "crusoe.nfs.remotePorts override renders" '"10.0.0.9-10.0.0.12"' \
  "$(env_values NFS_REMOTE_PORTS --set crusoe.nfs.remotePorts=10.0.0.9-10.0.0.12)"

echo
if [[ "$FAILED" -ne 0 ]]; then
  echo "==> FAILED"
  exit 1
fi
echo "==> all assertions passed"
