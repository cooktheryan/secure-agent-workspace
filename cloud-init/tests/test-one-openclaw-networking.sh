#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
agent_playbook="$repo_root/cloud-init/ansible/agent.yml"

grep -Fq 'openclaw_forward_port_cfg: 18788' "$agent_playbook"
grep -Fq 'ExecStart=/usr/local/bin/openshell forward start 127.0.0.1:{{ openclaw_forward_port_cfg }} {{ sandbox_name }}' "$agent_playbook"
grep -Fq 'OAUTH2_PROXY_HTTP_ADDRESS=0.0.0.0:{{ openclaw_proxy_port_cfg }}' "$agent_playbook"
grep -Fq 'OAUTH2_PROXY_UPSTREAMS=http://127.0.0.1:{{ openclaw_forward_port_cfg }}' "$agent_playbook"

if grep -Fq 'openclaw_proxy_bind_ip.stdout' "$agent_playbook"; then
  echo "agent playbook still depends on a discovered VM IP for OpenClaw proxy binding" >&2
  exit 1
fi

echo "VM one OpenClaw listener split is configured"
