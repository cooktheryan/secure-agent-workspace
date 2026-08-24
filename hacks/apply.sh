#!/usr/bin/env bash
# Launch the 'kind' Cirrus Server.
# The Cirrus operator creates the 'kind' Service from Server.spec.ports;
# other VMs in the namespace consume kind-hosted apps through that Service.
set -euo pipefail
NS=rh-vm-test1
DIR="$(cd "$(dirname "$0")" && pwd)"

# EPHEMERAL MODE: no persistent data disk; state is lost on VMI restart.
# The cluster is kind (Kubernetes in podman) — no subscription/pull secret needed.

echo ">> creating/updating cloud-init secret from cloudinit.userdata"
oc create secret generic kind-cloudinit -n "$NS" \
  --from-file=userdata="$DIR/cloudinit.userdata" \
  --dry-run=client -o yaml | oc apply -n "$NS" -f -

echo ">> applying server"
oc apply -n "$NS" -f "$DIR/server.yaml"

echo ">> waiting for the 'kind' Service (created by the Cirrus operator)"
for i in $(seq 1 30); do
  if oc get svc kind -n "$NS" >/dev/null 2>&1; then
    echo "   Service 'kind' is present"
    break
  fi
  sleep 5
  [ "$i" = "30" ] && { echo "!! timed out waiting for Service 'kind'"; exit 1; }
done

echo ">> done. Service:"
oc get svc kind -n "$NS"
