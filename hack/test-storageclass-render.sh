#!/usr/bin/env bash
# Render assertions for the StorageClass templates.
#
# These cover the cases that are easy to break silently: the classes must stay
# off by default so an upgrade never creates one, a class must not render
# without its driver, and boolean values must survive being set to false.
#
# Usage: hack/test-storageclass-render.sh [chart-dir]
set -euo pipefail

CHART="${1:-charts/crusoe-csi-driver}"
FAILED=0

pass() { printf '  ok    %s\n' "$1"; }
fail() { printf '  FAIL  %s\n' "$1"; FAILED=1; }

render() { helm template t "$CHART" "$@"; }

# Count StorageClass documents in a render.
count_sc() { render "$@" | grep -c '^kind: StorageClass' || true; }

check_eq() {
  local desc="$1" want="$2" got="$3"
  if [[ "$want" == "$got" ]]; then pass "$desc"; else fail "$desc (want '$want', got '$got')"; fi
}

echo "==> StorageClass render assertions ($CHART)"

# 1. Nothing by default. This is what keeps an upgrade from creating a class or
#    moving a cluster's default, so it is the assertion that matters most.
check_eq "defaults render no StorageClass" 0 "$(count_sc)"

# 2. The CMK bootstrap shape: both classes, shared filesystem as the default.
BOOTSTRAP=(--set storageClasses.fs.enabled=true
           --set storageClasses.fs.isDefault=true
           --set storageClasses.ssd.enabled=true)
check_eq "bootstrap values render both classes" 2 "$(count_sc "${BOOTSTRAP[@]}")"
check_eq "exactly one class is annotated default" 1 \
  "$(render "${BOOTSTRAP[@]}" | grep -c 'is-default-class' || true)"
check_eq "crusoe-fs is the default one" "crusoe-fs" \
  "$(render "${BOOTSTRAP[@]}" | awk '/^kind: StorageClass/{n=""} /^  name: /{n=$2} /is-default-class/{print n}')"

# 3. Provisioners must match the CSIDriver objects the same render produces.
for t in fs ssd; do
  check_eq "$t provisioner matches its CSIDriver" "$t.csi.crusoe.ai" \
    "$(render "${BOOTSTRAP[@]}" | awk -v want="$t.csi.crusoe.ai" '$1=="provisioner:" && $2==want {print $2}' | head -1)"
done

# 4. A class must not render without its driver, or its provisioner would have
#    no CSIDriver object and no pods behind it.
check_eq "class suppressed when its driver is disabled" 0 \
  "$(count_sc --set csi.fs.enabled=false --set storageClasses.fs.enabled=true)"

# 5. Booleans must not be coerced. Rendering these through `| default true`
#    would silently turn an explicit false back into true.
check_eq "allowVolumeExpansion=false survives" "allowVolumeExpansion: false" \
  "$(render --set storageClasses.fs.enabled=true --set storageClasses.fs.allowVolumeExpansion=false \
     | grep '^allowVolumeExpansion' | head -1)"

# 6. A values file that predates this section must not break the render.
if render --set storageClasses=null >/dev/null 2>&1; then
  pass "storageClasses=null still renders the chart"
else
  fail "storageClasses=null still renders the chart"
fi

# 7. Enabling a class with no name is a configuration error, not a nameless object.
if render --set storageClasses.fs.enabled=true --set storageClasses.fs.name="" >/dev/null 2>&1; then
  fail "enabling a class without a name is rejected"
else
  pass "enabling a class without a name is rejected"
fi

echo
if [[ "$FAILED" -ne 0 ]]; then
  echo "==> FAILED"
  exit 1
fi
echo "==> all assertions passed"
