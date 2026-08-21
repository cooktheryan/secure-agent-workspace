#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
site_playbook="$repo_root/cloud-init/ansible/site.yml"
integrations_vars="$repo_root/cloud-init/ansible/vars/integrations-vars.example.yml"
readme="$repo_root/cloud-init/README.md"

grep -Fq 'integration_proxy_embedding_model_cfg: "{{ integration_proxy_embedding_model | default('\''text-embedding-3-small'\'') }}"' "$site_playbook"
grep -Fq 'INTEGRATION_PROXY_EMBEDDING_MODEL={{ integration_proxy_embedding_model_cfg }}' "$site_playbook"
grep -Fq 'integration_proxy_embedding_model: text-embedding-3-small' "$integrations_vars"
grep -Fq 'integration proxy embeddings model' "$readme"

echo "Integration proxy exposes an embeddings-capable default model"
