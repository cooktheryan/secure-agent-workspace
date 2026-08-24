#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
agent_playbook="$repo_root/cloud-init/ansible/agent.yml"
agent_vars="$repo_root/cloud-init/ansible/vars/agent-vars.example.yml"
policy_template="$repo_root/cloud-init/ansible/templates/openclaw-policy.yml.j2"
bootstrap="$repo_root/cloud-init/ansible/files/bootstrap-openclaw-beta2-db.mjs"

grep -Fq 'sandbox_image: quay.io/rh-ai-quickstart/openclaw-openshell@sha256:a9113294df7bef4794b72c10415d9b883064d01ca044d6938269d601061b435f' "$agent_vars"
grep -Fq 'openclaw_demo_csb_enabled: false' "$agent_vars"
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
grep -Fq -- '--env NODE_DISABLE_COMPILE_CACHE=1' "$agent_playbook"
grep -Fq -- '--env OPENCLAW_DEFAULT_MODEL={{ inference_provider_cfg }}/{{ inference_model_cfg }}' "$agent_playbook"
grep -Fq -- '--env OPENCLAW_PROVIDERS=' "$agent_playbook"
grep -Fq 'export OPENCLAW_STATE_DIR=/sandbox/persist/.openclaw' "$agent_playbook"
grep -Fq 'export OPENCLAW_WORKSPACE_DIR=/sandbox/persist/workspace' "$agent_playbook"
grep -Fq 'export NODE_DISABLE_COMPILE_CACHE=1' "$agent_playbook"
grep -Fq 'node /tmp/bootstrap-openclaw-beta2-db.mjs' "$agent_playbook"
if grep -Fq 'openclaw --version | grep -Fq "2026.8.1-beta.2"' "$agent_playbook"; then
  echo "beta2 startup must not gate on openclaw --version because this image can exit 137 before gateway launch" >&2
  exit 1
fi
grep -Fq 'sandbox_state_after_delete=' "$agent_playbook"
grep -Fq '/usr/bin/timeout 30s /usr/local/bin/openshell sandbox delete {{ sandbox_name }}' "$agent_playbook"
grep -Fq 'OpenClaw sandbox delete timed out; cleaning matching rootless Podman containers before retry' "$agent_playbook"
grep -Fq 'OpenClaw sandbox remained in ${sandbox_state_after_delete} after delete; refusing to recreate yet' "$agent_playbook"
grep -Fq 'exec /app/entrypoint.sh >/tmp/openclaw-gateway.log 2>&1' "$agent_playbook"
grep -Fq 'node -e "const net = require(\"node:net\")' "$agent_playbook"
grep -Fq 'net.connect(18789, \"127.0.0.1\")' "$agent_playbook"
grep -Fq 'server.listen({ host: \"127.0.0.1\", port: {{ openclaw_forward_port_cfg }} });"' "$agent_playbook"
grep -Fq '[ "${sandbox_state}" = "Ready" ]' "$agent_playbook"
grep -Fq "curl -fsS http://127.0.0.1:18789/healthz" "$agent_playbook"
grep -Fq 'OpenClaw sandbox is Ready but the demo gateway is unhealthy; replacing it' "$agent_playbook"
openclaw_runtime_block="$(awk '/Write reference-aligned OpenClaw launch script/{in_block=1} in_block{print} in_block && /WantedBy=default.target/{exit}' "$agent_playbook")"
if grep -Fq 'gateway_pid=$!' <<<"$openclaw_runtime_block"; then
  echo "demo CSB gateway must stay in the foreground; backgrounding lets OpenShell reap the gateway" >&2
  exit 1
fi
grep -Fq 'OpenClaw demo gateway did not become healthy inside sandbox' <<<"$openclaw_runtime_block"
gateway_unit_block="$(awk '/Write openclaw gateway systemd user unit/{in_block=1} in_block{print} in_block && /WantedBy=default.target/{exit}' "$agent_playbook")"
grep -Fq 'Type=oneshot' <<<"$gateway_unit_block"
grep -Fq 'RemainAfterExit=true' <<<"$gateway_unit_block"
grep -Fq 'when: not (openclaw_demo_csb_enabled_cfg | bool)' "$agent_playbook"
forward_unit_block="$(awk '/Write openclaw foreground forward systemd user unit/{in_block=1} in_block{print} in_block && /WantedBy=default.target/{exit}' "$agent_playbook")"
grep -Fq 'Requires={% if openclaw_demo_csb_enabled_cfg | bool %}openclaw-sandbox.service{% else %}openclaw-gateway.service{% endif %}' <<<"$forward_unit_block"
grep -Fq 'After={% if openclaw_demo_csb_enabled_cfg | bool %}openclaw-sandbox.service{% else %}openclaw-gateway.service{% endif %}' <<<"$forward_unit_block"
sandbox_unit_block="$(awk '/Write openclaw sandbox systemd user unit/{in_block=1} in_block{print} in_block && /WantedBy=default.target/{exit}' "$agent_playbook")"
if grep -Fq 'Type={% if' <<<"$sandbox_unit_block"; then
  echo "sandbox unit must not render Type and Environment on one line" >&2
  exit 1
fi
grep -Fq 'Type=oneshot' <<<"$sandbox_unit_block"
grep -Fq 'RemainAfterExit=true' <<<"$sandbox_unit_block"
if grep -Fq 'Restart=on-failure' <<<"$sandbox_unit_block"; then
  echo "sandbox creation must not restart after OpenShell leaves a Ready sandbox behind" >&2
  exit 1
fi
grep -Fq 'disown "${create_pid}"' "$agent_playbook"
grep -Fq 'create_openclaw_sandbox >/tmp/openclaw-sandbox-create.log 2>&1 </dev/null &' "$agent_playbook"
grep -Fq 'OpenClaw sandbox create exited with rc=${create_rc}, but {{ sandbox_name }} is ${sandbox_state}; continuing' "$agent_playbook"
grep -Fq 'openclaw_service_units_cfg' "$agent_playbook"
grep -Fq "['openclaw-sandbox.service', 'openclaw-forward.service']" "$agent_playbook"
if grep -Fq 'OpenClaw sandbox create did not report a sandbox before timeout' "$agent_playbook"; then
  echo "sandbox service must not block waiting for sandbox list while create owns the gateway foreground" >&2
  exit 1
fi

echo "OpenClaw beta2 demo runtime contract is baked into saw-agent provisioning"
