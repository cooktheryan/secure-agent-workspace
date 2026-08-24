#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
agent_playbook="$repo_root/cloud-init/ansible/agent.yml"
agent_vars="$repo_root/cloud-init/ansible/vars/agent-vars.example.yml"

# The runtime config baked into cloud-init must match the live-good config that
# was validated in the OpenClaw UI: OpenClaw talks to OpenShell's inference
# route as an OpenAI-compatible completions provider, while oauth2-proxy supplies
# authenticated user identity via trusted-proxy headers.
grep -Fq "'baseUrl': inference_endpoint_url_cfg" "$agent_playbook"
grep -Fq "'api': 'openai-completions'" "$agent_playbook"
grep -Fq "'apiKey': inference_api_key_cfg" "$agent_playbook"
grep -Fq 'id: "{{ inference_model_cfg }}"' "$agent_playbook"
grep -Fq "reasoning: false" "$agent_playbook"
grep -Fq "openclaw config patch" "$agent_playbook"
grep -Fq "openclaw config unset gateway.auth.token || true" "$agent_playbook"
grep -Fq "'mode': 'local'" "$agent_playbook"
grep -Fq "'bind': 'lan'" "$agent_playbook"
grep -Fq "'mode': 'trusted-proxy'" "$agent_playbook"
grep -Fq "'userHeader': 'x-forwarded-preferred-username'" "$agent_playbook"
grep -Fq "'requiredHeaders': ['x-forwarded-proto', 'x-forwarded-host']" "$agent_playbook"
grep -Fq "'allowUsers': (openclaw_proxy_allowed_users | mandatory)" "$agent_playbook"
grep -Fq "'allowLoopback': true" "$agent_playbook"
grep -Fq "'trustedProxies': ['127.0.0.1', '::1']" "$agent_playbook"
grep -Fq "'allowedOrigins': [openclaw_route_origin_cfg]" "$agent_playbook"
grep -Fq "url: http://127.0.0.1:{{ openclaw_forward_port_cfg }}/ready" "$agent_playbook"
if grep -Fq "url: http://127.0.0.1:{{ openclaw_forward_port_cfg }}/health" "$agent_playbook"; then
  echo "OpenClaw gateway verifier must use the observed /ready endpoint, not /health" >&2
  exit 1
fi

auth_proxy_unit="$(awk '/Description=Keycloak-authenticated OpenClaw proxy/{in_unit=1} in_unit{print} in_unit && /WantedBy=default.target/{exit}' "$agent_playbook")"
grep -Fq "After=openclaw-forward.service" <<<"$auth_proxy_unit"
if grep -Fq "Requires=openclaw-forward.service" <<<"$auth_proxy_unit"; then
  echo "auth proxy must not require the OpenClaw one-shot dependency chain after it has been verified" >&2
  exit 1
fi
if grep -Fq "PartOf=openclaw-sandbox.service" <<<"$auth_proxy_unit"; then
  echo "auth proxy must not be coupled to the sandbox one-shot unit lifecycle" >&2
  exit 1
fi

if grep -Fq "openai-responses" "$agent_playbook"; then
  echo "agent playbook must not bake the failing openai-responses runtime provider for the live OpenClaw gateway" >&2
  exit 1
fi

if grep -Fq "supportsTemperature" "$agent_playbook"; then
  echo "agent playbook still carries responses-style compatibility metadata" >&2
  exit 1
fi

if grep -Fq "openclaw onboard" "$agent_playbook"; then
  echo "agent playbook must write runtime config directly instead of running killed onboarding at boot" >&2
  exit 1
fi

gateway_launcher="$(awk '/dest: "{{ user_home }}\/\.local\/bin\/start-openclaw-gateway"/{in_launcher=1} in_launcher{print} in_launcher && /dest: "{{ user_home }}\/\.config\/systemd\/user\/openclaw-gateway.service"/{exit}' "$agent_playbook")"
if grep -Fq "nohup openclaw gateway run" <<<"$gateway_launcher"; then
  echo "OpenClaw gateway must run in the foreground so systemd tracks the real process" >&2
  exit 1
fi
if grep -Fq ">/tmp/openclaw-gateway.log 2>&1 </dev/null &" <<<"$gateway_launcher"; then
  echo "OpenClaw gateway launcher must not background the gateway before health checks" >&2
  exit 1
fi

gateway_unit="$(awk '/Description=OpenClaw gateway process inside OpenShell sandbox/{in_unit=1} in_unit{print} in_unit && /WantedBy=default.target/{exit}' "$agent_playbook")"
grep -Fq "Type=simple" <<<"$gateway_unit"
if grep -Fq "RemainAfterExit=true" <<<"$gateway_unit"; then
  echo "OpenClaw gateway unit must not remain active after the launcher exits" >&2
  exit 1
fi

if awk '
  /openshell sandbox create/ { in_create=1 }
  in_create && /--provider {{ inference_provider_name }}/ { found=1 }
  in_create && /sandbox-ready/ { in_create=0 }
  END { exit found ? 0 : 1 }
' "$agent_playbook"; then
  echo "agent playbook must not create provider-bound OpenClaw sandboxes because the runtime exits 137 there" >&2
  exit 1
fi

grep -Fq "inference_model: rits/zai-org/glm-5-2-fp8" "$agent_vars"
grep -Fq "inference_provider: glm" "$agent_vars"
grep -Fq 'https://saw-integ.${NS}.svc.cluster.local:18083/v1' "$agent_vars"
grep -Fq 'inference_https_proxy: ""' "$agent_vars"

echo "saw-agent OpenClaw runtime config is baked for the live-good provider and trusted proxy"
