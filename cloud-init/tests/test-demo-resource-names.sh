#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
agent_manifest="$repo_root/cloud-init/kubernetes/agent-server.yml"
integrations_manifest="$repo_root/cloud-init/kubernetes/integrations-server.yml"
agent_vars="$repo_root/cloud-init/ansible/vars/agent-vars.example.yml"
integrations_vars="$repo_root/cloud-init/ansible/vars/integrations-vars.example.yml"
readme="$repo_root/cloud-init/README.md"

for path in "$agent_manifest" "$integrations_manifest" "$agent_vars" "$integrations_vars"; do
  test -f "$path" || {
    echo "missing expected demo asset: ${path#$repo_root/}" >&2
    exit 1
  }
done

grep -Fq 'name: saw-agent' "$agent_manifest"
grep -Fq 'hostname: saw-agent' "$agent_manifest"
grep -Fq 'secretName: saw-agent-vars' "$agent_manifest"
grep -Fq 'claimName: saw-agent-state-persist' "$agent_manifest"
grep -Fq 'claimName: saw-agent-assets-persist' "$agent_manifest"

grep -Fq 'name: saw-integ' "$integrations_manifest"
grep -Fq 'hostname: saw-integ' "$integrations_manifest"
grep -Fq 'secretName: saw-integ-vars' "$integrations_manifest"
grep -Fq 'claimName: saw-integ-persist' "$integrations_manifest"

grep -Fq 'hostname: saw-agent' "$agent_vars"
grep -Fq 'hostname: saw-integ' "$integrations_vars"
grep -Fq 'https://saw-integ.${NS}.svc.cluster.local:18083/v1' "$agent_vars"

grep -Fq 'saw-agent' "$readme"
grep -Fq 'saw-integ' "$readme"

if grep -R 'feat/two-persist-pvc' "$agent_manifest" "$integrations_manifest"; then
  echo "cloud-init still bootstraps from the known-good PVC branch instead of the new demo branch" >&2
  exit 1
fi

echo "OpenClaw SAW demo resource names are configured"
