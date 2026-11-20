#!/usr/bin/env bash
# Render assertions for the controller sidecar --timeout flags.
#
# The driver waits up to 5m for each Crusoe API operation, so the attacher,
# provisioner and resizer must wait longer, or they cancel the call before the
# driver reports why it failed. These checks keep the default above 5m, keep
# overrides and opt-outs working, and keep old values files rendering.
#
# Usage: hack/test-sidecar-timeout-render.sh [chart-dir]
set -euo pipefail

CHART="${1:-charts/crusoe-csi-driver}"
FAILED=0
SIDECARS=(csi-attacher csi-provisioner csi-resizer)

pass() { printf '  ok    %s\n' "$1"; }
fail() { printf '  FAIL  %s\n' "$1"; FAILED=1; }

render() { helm template t "$CHART" "$@"; }

# Print the --timeout arg of every container named $1, one line per controller.
timeouts_for() {
  local container="$1"; shift
  render "$@" | awk -v c="$container" '
    /^kind: /             { in_ctrl = ($2 == "Deployment") }
    /^        - name: /   { cur = $3 }
    in_ctrl && cur == c && /--timeout=/ { gsub(/[" -]/, ""); print }
  '
}

check_eq() {
  local desc="$1" want="$2" got="$3"
  if [[ "$want" == "$got" ]]; then pass "$desc"; else fail "$desc (want '$want', got '$got')"; fi
}

echo "==> Sidecar timeout render assertions ($CHART)"

# 1. Defaults: every sidecar in both controllers (fs and ssd) waits 6m.
for s in "${SIDECARS[@]}"; do
  check_eq "$s defaults to --timeout=6m in both controllers" $'timeout=6m\ntimeout=6m' \
    "$(timeouts_for "$s")"
done

# 2. An override reaches only the sidecar it names.
check_eq "provisioner override applies" $'timeout=10m\ntimeout=10m' \
  "$(timeouts_for csi-provisioner --set controller.provisioner.timeout=10m)"
check_eq "provisioner override leaves the resizer alone" $'timeout=6m\ntimeout=6m' \
  "$(timeouts_for csi-resizer --set controller.provisioner.timeout=10m)"

# 3. An empty value drops the flag, so the sidecar uses its own default.
# Check the render first: a failed render also yields no flag.
if render --set controller.provisioner.timeout= >/dev/null 2>&1; then
  pass "empty timeout renders"
  check_eq "empty timeout renders no flag" "" \
    "$(timeouts_for csi-provisioner --set controller.provisioner.timeout=)"
else
  fail "empty timeout renders"
fi

# 4. Values that predate these keys (e.g. --reuse-values from 0.10.29) render with no --timeout flag.
NULLS=(--set controller.attacher.timeout=null --set controller.provisioner.timeout=null --set controller.resizer.timeout=null)
render "${NULLS[@]}" >/dev/null || fail "values without timeout keys render"
for s in "${SIDECARS[@]}"; do
  check_eq "$s renders no --timeout when the key is absent" "" "$(timeouts_for "$s" "${NULLS[@]}")"
done

if [[ "$FAILED" -ne 0 ]]; then
  echo "FAILED"
  exit 1
fi
echo "PASSED"
