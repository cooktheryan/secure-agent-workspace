#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
agent_playbook="$repo_root/cloud-init/ansible/agent.yml"

grep -Fq "api: openai-completions" "$agent_playbook"
grep -Fq "'api': 'openai-completions'" "$agent_playbook"

if grep -Fq "api: openai-responses" "$agent_playbook" ||
  grep -Fq "'api': 'openai-responses'" "$agent_playbook"; then
  echo "agent playbook still configures OpenClaw for /v1/responses" >&2
  exit 1
fi

echo "OpenClaw model API uses chat completions for the integration proxy"
