#!/usr/bin/env bash
set -euo pipefail

repo_owner="${SAW_REPO_OWNER:-cooktheryan}"
repo_name="${SAW_REPO_NAME:-secure-agent-workspace}"
repo_branch="${SAW_REPO_BRANCH:-feat/openclaw-demo-alignment}"
checkout="${SAW_CHECKOUT_DIR:-/opt/secure-agent-workspace}"
vars_mount="${SAW_VARS_MOUNT:-/etc/openshell-saw}"

install -d -m 0750 "${vars_mount}"
vars_device=""
for attempt in $(seq 1 36); do
  udevadm settle --timeout=5 || true
  vars_device="$(lsblk -rpno NAME,SERIAL | awk '$2=="VARS01"{print $1;exit}')"
  if [ -n "${vars_device}" ]; then
    break
  fi
  echo "waiting for VARS01 vars disk (attempt ${attempt}/36)"
  lsblk -rpno NAME,SERIAL,FSTYPE,SIZE,MOUNTPOINT || true
  sleep 10
done

if [ -z "${vars_device}" ]; then
  echo "VARS01 vars disk was not found" >&2
  lsblk -rpno NAME,SERIAL,FSTYPE,SIZE,MOUNTPOINT >&2 || true
  exit 1
fi

mountpoint -q "${vars_mount}" || mount -o ro "${vars_device}" "${vars_mount}"
test -f "${vars_mount}/vars.yml"
echo "mounted ${vars_device} at ${vars_mount}"

install -d -m 0755 "${checkout}"
curl -fsSL --retry 5 --retry-delay 10 \
  "https://github.com/${repo_owner}/${repo_name}/archive/refs/heads/${repo_branch}.tar.gz" \
  | tar -xz --strip-components=1 -C "${checkout}"

usermod --add-subuids 100000-165535 --add-subgids 100000-165535 openshell 2>/dev/null || true

install -m 0755 "${checkout}/cloud-init/files/saw-provision-debug-server.py" /usr/local/sbin/saw-provision-debug-server
cat >/etc/systemd/system/saw-provision-log-http.service <<'UNIT'
[Unit]
Description=SAW provisioning diagnostic HTTP endpoint
After=network-online.target
Wants=network-online.target

[Service]
ExecStart=/usr/local/sbin/saw-provision-debug-server
Restart=on-failure
RestartSec=2

[Install]
WantedBy=multi-user.target
UNIT
systemctl daemon-reload
systemctl enable --now saw-provision-log-http.service

systemd-run \
  --unit=saw-provision.service \
  --setenv=HOME=/root \
  /usr/bin/bash -c "exec /usr/bin/ansible-playbook -i localhost, ${checkout}/cloud-init/ansible/site.yml -e @${vars_mount}/vars.yml > /var/log/saw-provision.log 2>&1"
