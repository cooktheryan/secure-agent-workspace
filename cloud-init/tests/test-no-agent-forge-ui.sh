#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
agent_playbook="$repo_root/cloud-init/ansible/agent.yml"
agent_vars="$repo_root/cloud-init/ansible/vars/agent-vars.example.yml"
agent_manifest="$repo_root/cloud-init/kubernetes/agent-server.yml"
readme="$repo_root/cloud-init/README.md"
runbook="$repo_root/docs/two""-vm-cloud-init-runbook.md"
tracker="$repo_root/docs/openclaw-saw-demo-alignment-tracker.md"

test ! -e "$repo_root/cloud-init/kubernetes/agent-forge-ui-route.yml"
test ! -e "$repo_root/cloud-init/kubernetes/forge-ui-ui-only.yml"

grep -Fq 'name: userport' "$agent_manifest"
grep -Fq 'port: 18789' "$agent_manifest"
grep -Fq 'name: provisionlog' "$agent_manifest"
grep -Fq 'port: 18080' "$agent_manifest"

if grep -RInE 'forge_ui|forge_relay|forge-ui\\.service|forge-relay\\.service|start-forge|FORGE_GATEWAY_URL|FORGE_RELAY|podman run --rm --name forge-(ui|relay)|saw-agent-forge-ui|rh-forge-ui|18090|18091|18092|quay.io/rcook/rh-forge-ui' \
  "$agent_playbook" \
  "$agent_vars" \
  "$agent_manifest" \
  "$readme" \
  "$runbook"; then
  echo "saw-agent must not deploy or expose Forge UI; it is hosted remotely" >&2
  exit 1
fi

echo "saw-agent Forge UI deployment assets are removed"
