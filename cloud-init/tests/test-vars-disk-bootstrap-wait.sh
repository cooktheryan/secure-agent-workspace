#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
manifests=(
  "$repo_root/cloud-init/kubernetes/agent-server.yml"
  "$repo_root/cloud-init/kubernetes/integrations-server.yml"
)
bootstrap="$repo_root/cloud-init/files/bootstrap-server.sh"

test -f "$bootstrap"
grep -Fq 'for attempt in $(seq 1 36); do' "$bootstrap"
grep -Fq 'udevadm settle --timeout=5 || true' "$bootstrap"
grep -Fq 'waiting for VARS01 vars disk (attempt ${attempt}/36)' "$bootstrap"
grep -Fq 'VARS01 vars disk was not found' "$bootstrap"
grep -Fq 'mountpoint -q "${vars_mount}" || mount -o ro "${vars_device}" "${vars_mount}"' "$bootstrap"
grep -Fq 'test -f "${vars_mount}/vars.yml"' "$bootstrap"
grep -Fq 'mounted ${vars_device} at ${vars_mount}' "$bootstrap"
grep -Fq 'saw-provision-log-http.service' "$bootstrap"
grep -Fq '/var/log/saw-provision.log' "$bootstrap"

for manifest in "${manifests[@]}"; do
  test -f "$manifest"
  grep -Fq 'raw.githubusercontent.com/cooktheryan/secure-agent-workspace/feat/openclaw-demo-alignment/cloud-init/files/bootstrap-server.sh' "$manifest"
  grep -Fq 'bash /tmp/saw-bootstrap-server.sh' "$manifest"
done

echo "VM cloud-init waits for VARS01 before provisioning"
