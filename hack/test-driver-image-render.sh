#!/usr/bin/env bash
# Render assertions for the per-type driver image (csi.<type>.image).
#
# Each CSI type (ssd, fs) renders a node DaemonSet and a controller Deployment.
# By default all four take the crusoe-csi-driver image from the shared
# node/controller values. csi.<type>.image overrides it for one type only, field
# by field, and global.imageRegistry still wins over any registry.
#
# Usage: hack/test-driver-image-render.sh [chart-dir]
set -euo pipefail

CHART="${1:-charts/crusoe-csi-driver}"
FAILED=0

pass() { printf '  ok    %s\n' "$1"; }
fail() { printf '  FAIL  %s\n' "$1"; FAILED=1; }

check_eq() {
  local desc="$1" want="$2" got="$3"
  if [[ "$want" == "$got" ]]; then pass "$desc"; else fail "$desc (want '$want', got '$got')"; fi
}

# One line per driver workload: "<type>-<role> <crusoe-csi-driver image>",
# sorted, e.g. "fs-controller ghcr.io/crusoecloud/crusoe-csi-driver:v0.4.21".
images() {
  helm template t "$CHART" \
    --show-only templates/daemonsets/node.yaml \
    --show-only templates/deployments/controller.yaml "$@" |
    awk '/^  name: /                 { sub(/^t-crusoe-csi-driver-/, "", $2); name = $2 }
         /- name: crusoe-csi-driver$/ { want = 1; next }
         want && /image:/             { gsub(/"/, "", $2); print name, $2; want = 0 }' |
    sort | tr '\n' ';'
}

# Default chart's driver version and image
APP=$(awk '/^appVersion:/ { gsub(/"/, "", $2); print $2 }' "$CHART/Chart.yaml")
DEF="ghcr.io/crusoecloud/crusoe-csi-driver:$APP"
# a fake "new" image used by the checks
NEW="ghcr.io/crusoecloud/crusoe-csi-driver:v9.9.9"

echo "==> driver image render assertions ($CHART)"

# 1. No override: all four workloads use the shared image.
check_eq "default: all four use the shared image" \
  "fs-controller $DEF;fs-node $DEF;ssd-controller $DEF;ssd-node $DEF;" \
  "$(images)"

# 2. An fs tag moves only the fs workloads.
check_eq "csi.fs.image.tag changes only fs-node and fs-controller" \
  "fs-controller $NEW;fs-node $NEW;ssd-controller $DEF;ssd-node $DEF;" \
  "$(images --set csi.fs.image.tag=v9.9.9)"

# 3. An ssd tag moves only the ssd workloads.
check_eq "csi.ssd.image.tag changes only ssd-node and ssd-controller" \
  "fs-controller $DEF;fs-node $DEF;ssd-controller $NEW;ssd-node $NEW;" \
  "$(images --set csi.ssd.image.tag=v9.9.9)"

# 4. Fields fall back one by one: registry and repository set, tag from shared.
check_eq "unset tag falls back to the shared tag" \
  "fs-controller my.reg/myorg/driver:$APP;fs-node my.reg/myorg/driver:$APP;ssd-controller $DEF;ssd-node $DEF;" \
  "$(images --set csi.fs.image.registry=my.reg --set csi.fs.image.repository=myorg/driver)"

# 5. global.imageRegistry wins over a per-type registry.
check_eq "global.imageRegistry wins over csi.fs.image.registry" \
  "fs-controller g.reg/crusoe-csi-driver:v9.9.9;fs-node g.reg/crusoe-csi-driver:v9.9.9;ssd-controller g.reg/crusoe-csi-driver:$APP;ssd-node g.reg/crusoe-csi-driver:$APP;" \
  "$(images --set global.imageRegistry=g.reg --set csi.fs.image.registry=other.reg --set csi.fs.image.tag=v9.9.9)"

# 6. When the shared node and controller tags differ, an override on one type
#    replaces both of that type's images, and the other type keeps using the
#    shared tag for each role.
#      Set:    controller tag v8.8.8, node tag left at the chart default ($APP),
#              csi.ssd.image.tag v9.9.9
#      Expect: ssd-node v9.9.9, ssd-controller v9.9.9   (override)
#              fs-node  $APP,   fs-controller  v8.8.8   (shared, per role)
check_eq "ssd override wins over differing shared tags; fs keeps them" \
  "fs-controller ghcr.io/crusoecloud/crusoe-csi-driver:v8.8.8;fs-node $DEF;ssd-controller $NEW;ssd-node $NEW;" \
  "$(images --set controller.crusoeCsiDriver.image.tag=v8.8.8 --set csi.ssd.image.tag=v9.9.9)"

# 7. A disabled type renders nothing, override or not.
check_eq "disabled fs renders no fs workloads" \
  "ssd-controller $DEF;ssd-node $DEF;" \
  "$(images --set csi.fs.enabled=false --set csi.fs.image.tag=v9.9.9)"

# 8. Nothing else in the chart changes: exactly the two fs driver image lines.
#    Unified diff, because busybox diff (the CI image) has no normal format.
#    Count added lines, skipping the "+++" file header.
check_eq "fs override changes exactly 2 lines in the full render" 2 \
  "$(diff -u <(helm template t "$CHART") <(helm template t "$CHART" --set csi.fs.image.tag=v9.9.9) | grep -c '^+[^+]' || true)"

if [[ "$FAILED" -ne 0 ]]; then
  echo "==> FAILED"
  exit 1
fi
echo "==> all passed"
