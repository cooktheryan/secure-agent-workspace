#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

ansible-playbook \
  -i localhost, \
  "$repo_root/cloud-init/ansible/site.yml" \
  -e @"$repo_root/cloud-init/ansible/vars/agent-vars.example.yml" \
  --syntax-check >/dev/null

ansible-playbook \
  -i localhost, \
  "$repo_root/cloud-init/ansible/agent.yml" \
  -e @"$repo_root/cloud-init/ansible/vars/agent-vars.example.yml" \
  --syntax-check >/dev/null
