#!/usr/bin/env bash
# Render assertions for csi.fs.nfsLockServices, which the NFS prerequisites
# script reads as Python constants. Upgrades with --reuse-values keep the values
# stored at install time, so a release installed before these values existed must
# still render with statd enabled on port 662.
#
# Usage: hack/test-nfs-lock-render.sh [chart-dir]
set -euo pipefail

CHART="${1:-charts/crusoe-csi-driver}"
FAILED=0

pass() { printf '  ok    %s\n' "$1"; }
fail() { printf '  FAIL  %s\n' "$1"; FAILED=1; }

render() { helm template t "$CHART" --show-only templates/configmaps/install-nfs-prerequisites-script.yaml "$@"; }

# Value of one constant in the rendered script, e.g. "STATD_PORT".
const() {
  local name="$1"; shift
  render "$@" | awk -v n="$name" '$1==n && $2=="=" {print $3}'
}

check_eq() {
  local desc="$1" want="$2" got="$3"
  if [[ "$want" == "$got" ]]; then pass "$desc"; else fail "$desc (want '$want', got '$got')"; fi
}

check_fails() {
  local desc="$1"; shift
  if render "$@" >/dev/null 2>&1; then fail "$desc (rendered, want failure)"; else pass "$desc"; fi
}

echo "nfsLockServices defaults"
check_eq "enabled by default" "True" "$(const NFS_LOCK_SERVICES)"
check_eq "port 662 by default" "662" "$(const STATD_PORT)"

echo "values stored before nfsLockServices existed (--reuse-values upgrade)"
check_eq "enabled when the block is absent" "True" "$(const NFS_LOCK_SERVICES --set csi.fs.nfsLockServices=null)"
check_eq "port 662 when the block is absent" "662" "$(const STATD_PORT --set csi.fs.nfsLockServices=null)"

echo "overrides"
check_eq "enabled=false" "False" "$(const NFS_LOCK_SERVICES --set csi.fs.nfsLockServices.enabled=false)"
check_eq "statdPort=4000" "4000" "$(const STATD_PORT --set csi.fs.nfsLockServices.statdPort=4000)"
check_fails "statdPort in the NodePort range" --set csi.fs.nfsLockServices.statdPort=30000
check_fails "statdPort=111 (rpcbind)" --set csi.fs.nfsLockServices.statdPort=111

exit "$FAILED"
