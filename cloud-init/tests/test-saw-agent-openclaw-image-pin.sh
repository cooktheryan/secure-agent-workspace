#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
agent_vars="$repo_root/cloud-init/ansible/vars/agent-vars.example.yml"
feature="$repo_root/cloud-init/features/0002_saw_agent_persistence.feature"
readme="$repo_root/cloud-init/README.md"
tracker="$repo_root/docs/openclaw-saw-demo-alignment-tracker.md"

expected_image="quay.io/rh-forge/openclaw-saw:2026.8.1-beta.2-20260821160256"

grep -Fq "sandbox_image: ${expected_image}" "$agent_vars"
grep -Fq "pinned demo OpenClaw runtime image" "$feature"
grep -Fq "$expected_image" "$readme"
grep -Fq "$expected_image" "$tracker"

if grep -Fq "quay.io/rh-ai-quickstart/openclaw-openshell@sha256:f6226599b9bff9475bb0597e49d1612866597e319a0a63ac59e8eea7f864f32c" "$agent_vars"; then
  echo "saw-agent vars still reference the previous OpenClaw runtime image" >&2
  exit 1
fi

echo "saw-agent OpenClaw runtime image is pinned to the demo image"
