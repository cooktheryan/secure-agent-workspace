#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
site_playbook="$repo_root/cloud-init/ansible/site.yml"

if grep -Fq 'python3-pip' "$site_playbook"; then
  echo "role dispatcher still requires python3-pip, which is unavailable on the VM one base image" >&2
  exit 1
fi

echo "VM one role dispatch packages avoid python3-pip"
