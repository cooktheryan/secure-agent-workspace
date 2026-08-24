#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
manifests=(
  "$repo_root/cloud-init/kubernetes/agent-server.yml"
  "$repo_root/cloud-init/kubernetes/integrations-server.yml"
)

for manifest in "${manifests[@]}"; do
  test -f "$manifest"
  grep -Fq 'for attempt in $(seq 1 36); do' "$manifest"
  grep -Fq 'udevadm settle --timeout=5 || true' "$manifest"
  grep -Fq 'waiting for VARS01 vars disk (attempt ${attempt}/36)' "$manifest"
  grep -Fq 'VARS01 vars disk was not found' "$manifest"
  grep -Fq 'mountpoint -q /etc/openshell-saw || mount -o ro "${vars_device}" /etc/openshell-saw' "$manifest"
  grep -Fq 'test -f /etc/openshell-saw/vars.yml' "$manifest"
  grep -Fq 'mounted ${vars_device} at /etc/openshell-saw' "$manifest"
done

echo "VM cloud-init waits for VARS01 before provisioning"
