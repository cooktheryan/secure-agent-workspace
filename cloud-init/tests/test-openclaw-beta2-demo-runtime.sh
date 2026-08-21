#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
agent_playbook="$repo_root/cloud-init/ansible/agent.yml"
agent_vars="$repo_root/cloud-init/ansible/vars/agent-vars.example.yml"
policy_template="$repo_root/cloud-init/ansible/templates/openclaw-policy.yml.j2"
bootstrap="$repo_root/cloud-init/ansible/files/bootstrap-openclaw-beta2-db.mjs"

grep -Fq 'sandbox_image: quay.io/rh-forge/openclaw-saw:2026.8.1-beta.2-20260821160256' "$agent_vars"
grep -Fq 'openclaw_demo_csb_enabled: true' "$agent_vars"
grep -Fq 'openclaw_sandbox_uid: "1000"' "$agent_vars"
grep -Fq 'openclaw_sandbox_gid: "1000"' "$agent_vars"

test -f "$bootstrap"
grep -Fq 'DatabaseSync' "$bootstrap"
grep -Fq 'openclaw_beta2_bootstrap' "$bootstrap"

test -f "$policy_template"
grep -Fq 'run_as_user: "{{ openclaw_sandbox_uid_cfg }}"' "$policy_template"
grep -Fq 'run_as_group: "{{ openclaw_sandbox_gid_cfg }}"' "$policy_template"

grep -Fq 'openclaw_demo_csb_enabled_cfg: "{{ openclaw_demo_csb_enabled | default(false) }}"' "$agent_playbook"
grep -Fq 'openclaw_sandbox_uid_cfg: "{{ openclaw_sandbox_uid | default(' "$agent_playbook"
grep -Fq 'dest: "{{ user_home }}/.config/openshell/openclaw-policy.yml"' "$agent_playbook"
grep -Fq 'openclaw_demo_podman_volume: openclaw-saw-data' "$agent_playbook"
grep -Fq '/usr/bin/podman volume create --ignore {{ openclaw_demo_podman_volume }}' "$agent_playbook"
grep -Fq 'target":"/sandbox/persist"' "$agent_playbook"
grep -Fq -- '--upload {{ playbook_dir }}/files/bootstrap-openclaw-beta2-db.mjs:/tmp/bootstrap-openclaw-beta2-db.mjs' "$agent_playbook"
grep -Fq -- '--env OPENCLAW_GATEWAY_TOKEN="${gateway_token}"' "$agent_playbook"
grep -Fq -- '--env OPENCLAW_STATE_DIR=/sandbox/persist/.openclaw' "$agent_playbook"
grep -Fq -- '--env OPENCLAW_WORKSPACE_DIR=/sandbox/persist/workspace' "$agent_playbook"
grep -Fq -- '--env OPENCLAW_NO_RESPAWN=1' "$agent_playbook"
grep -Fq -- '--env OPENCLAW_DEFAULT_MODEL={{ inference_provider_cfg }}/{{ inference_model_cfg }}' "$agent_playbook"
grep -Fq -- '--env OPENCLAW_PROVIDERS=' "$agent_playbook"
grep -Fq 'node /tmp/bootstrap-openclaw-beta2-db.mjs' "$agent_playbook"
grep -Fq 'nohup /app/entrypoint.sh' "$agent_playbook"

echo "OpenClaw beta2 demo runtime contract is baked into saw-agent provisioning"
