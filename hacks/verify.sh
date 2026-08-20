#!/usr/bin/env bash
# Full validation for the 'kind' Cirrus VM + kind cluster.
#
# Layer 1 (from this workstation, via oc): the Cirrus Server, VMI, Service, and
# cloud-init Secret exist and expose the right ports.
# Layer 2 (inside the VM, via 'virtctl ssh'): kind is installed, running,
# the node is Ready, and control-plane pods are up (flags the
# ephemeral-disk compromise if present).
#
# All checks run to completion; a summary prints at the end and the script exits
# non-zero if any hard check failed. In-VM checks are skipped (not failed) when
# virtctl ssh is not permitted for this user.
#
# Env overrides: NS, VM, VIRTCTL_USER, FROM_VM (another VM to test cross-VM
# reachability of the vault NodePort from).
set -uo pipefail

NS="${NS:-rh-vm-test1}"
VM="${VM:-kind}"
VIRTCTL_USER="${VIRTCTL_USER:-$USER}"
FROM_VM="${FROM_VM:-}"

pass=0; fail=0; warn=0
ok()   { echo "  [PASS] $*"; pass=$((pass+1)); }
bad()  { echo "  [FAIL] $*" >&2; fail=$((fail+1)); }
note() { echo "  [WARN] $*"; warn=$((warn+1)); }

echo "== Layer 1: cluster-side (oc) =="

echo ">> Cirrus Server '$VM'"
if oc get server "$VM" -n "$NS" >/dev/null 2>&1; then ok "server/$VM exists"; else bad "server/$VM missing"; fi

echo ">> VMI '$VM'"
phase="$(oc get vmi "$VM" -n "$NS" -o jsonpath='{.status.phase}' 2>/dev/null || true)"
vmip="$(oc get vmi "$VM" -n "$NS" -o jsonpath='{.status.interfaces[0].ipAddress}' 2>/dev/null || true)"
if [[ "$phase" == "Running" ]]; then ok "vmi/$VM Running (ip ${vmip:-unknown})"
else bad "vmi/$VM phase='${phase:-none}' (not Running yet)"; fi

echo ">> Service '$VM' + ports"
if oc get svc "$VM" -n "$NS" >/dev/null 2>&1; then
  ok "svc/$VM exists"
  ports="$(oc get svc "$VM" -n "$NS" -o jsonpath='{.spec.ports[*].port}' 2>/dev/null)"
  for p in 6443 30820; do
    if grep -qw "$p" <<<"$ports"; then ok "svc/$VM exposes port $p"; else bad "svc/$VM missing port $p (have: $ports)"; fi
  done
else bad "svc/$VM missing"; fi

echo ">> cloud-init Secret 'kind-cloudinit'"
if oc get secret kind-cloudinit -n "$NS" >/dev/null 2>&1; then ok "secret/kind-cloudinit exists"; else bad "secret/kind-cloudinit missing"; fi

echo
echo "== Layer 2: in-VM kind cluster health (via virtctl ssh) =="

# One remote script. kind runs rootful under podman, so use sudo.
read -r -d '' REMOTE <<'REMOTE_EOF' || true
set -u
export KIND_EXPERIMENTAL_PROVIDER=podman
echo "PODMAN=$(command -v podman >/dev/null 2>&1 && echo installed || echo absent)"
echo "KIND=$(command -v kind >/dev/null 2>&1 && echo installed || echo absent)"
echo "CLUSTER=$(sudo -E kind get clusters 2>/dev/null | grep -qx kind && echo present || echo absent)"
KC=/home/cloud-user/.kube/config
NODE="$(sudo env KUBECONFIG=$KC kubectl get nodes --no-headers 2>/dev/null | awk '{print $2}' | head -1)"
echo "NODE_STATUS=${NODE:-unavailable}"
NOTREADY="$(sudo env KUBECONFIG=$KC kubectl get pods -A --no-headers 2>/dev/null | awk '$4!="Running" && $4!="Completed"{c++} END{print c+0}')"
echo "PODS_NOTREADY=${NOTREADY:-unknown}"
if lsblk --nodeps -no name,serial 2>/dev/null | grep -qw MSDATA1; then echo "DATA_DISK=present"; else echo "DATA_DISK=absent"; fi
REMOTE_EOF

remote_out="$(virtctl ssh -n "$NS" -l "$VIRTCTL_USER" "vm/$VM" --command "$REMOTE" 2>/dev/null)"
if [[ -z "$remote_out" ]]; then
  note "virtctl ssh returned nothing (not permitted, or VM/cluster not up yet)."
  note "Run the checks manually from an SSH session on the VM (see README 'Validation')."
else
  get() { grep -m1 "^$1=" <<<"$remote_out" | cut -d= -f2-; }
  [[ "$(get PODMAN)" == "installed" ]] && ok "podman installed" || bad "podman $(get PODMAN)"
  [[ "$(get KIND)" == "installed" ]] && ok "kind installed" || bad "kind $(get KIND)"
  [[ "$(get CLUSTER)" == "present" ]] && ok "kind cluster 'kind' present" || bad "kind cluster absent"
  [[ "$(get NODE_STATUS)" == "Ready" ]] && ok "node Ready" || bad "node status = $(get NODE_STATUS)"
  np="$(get PODS_NOTREADY)"
  if [[ "$np" == "0" ]]; then ok "all pods Running/Completed"; else bad "$np pod(s) not Running"; fi

  [[ "$(get DATA_DISK)" == "present" ]] && ok "persistent data disk MSDATA1 attached" \
    || note "ephemeral mode: no MSDATA1 disk (kind state lost on restart)"
fi

# Optional: prove another VM can reach the vault NodePort through the Service.
if [[ -n "$FROM_VM" ]]; then
  echo
  echo "== Cross-VM reachability from '$FROM_VM' =="
  if virtctl ssh -n "$NS" -l "$VIRTCTL_USER" "vm/$FROM_VM" \
       --command "timeout 5 bash -c '</dev/tcp/$VM.$NS.svc.cluster.local/30820' 2>/dev/null" >/dev/null 2>&1; then
    ok "$FROM_VM can TCP-connect to $VM:30820 (deploy Vault with nodePort 30820 to serve it)"
  else
    note "$FROM_VM could not connect to $VM:30820 (expected until a NodePort app listens there)"
  fi
fi

echo
echo "== Summary: $pass passed, $fail failed, $warn warning(s) =="
[[ "$fail" -eq 0 ]] && { echo "validation passed"; exit 0; } || { echo "validation FAILED"; exit 1; }
