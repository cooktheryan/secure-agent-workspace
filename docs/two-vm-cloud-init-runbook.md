# Two-VM cloud-init deployment runbook

This runbook is the operator-facing path for reproducing the current two-VM
Secure Agent Workspace deployment in OpenShift/Cirrus.

It assumes the branch or PR contains the `cloud-init/` assets for:

- `saw-integ`: the integration VM that hosts the OpenAI-compatible HTTPS
  inference proxy.
- `saw-agent`: the agent VM that hosts OpenShell, the OpenClaw sandbox,
  the authenticated OpenClaw route, and persistent OpenClaw state.

The detailed secret schema and reference-name notes live in
[`cloud-init/README.md`](../cloud-init/README.md). This file is the shorter
“do this, then verify this” runbook.

## 1. Deployment shape

Default OpenShift/Cirrus resources:

| Purpose | Resource |
| --- | --- |
| Agent VM | `Server/saw-agent` |
| Integration VM | `Server/saw-integ` |
| Agent config Secret | `Secret/saw-agent-vars` |
| Integration config Secret | `Secret/saw-integ-vars` |
| Agent state PVC | `saw-agent-state-persist` |
| Agent assets/container PVC | `saw-agent-assets-persist` |
| Integration persistence PVC | `saw-integ-persist` |
| OpenClaw browser Route | `Route/saw-agent-openclaw` |
| OpenClaw sandbox name | `openclaw-saw` |

Expected PVC sizing used during validation:

| PVC | Suggested size |
| --- | ---: |
| `saw-agent-state-persist` | 10 GiB |
| `saw-agent-assets-persist` | 50 GiB |
| `saw-integ-persist` | 10 GiB |

The VM IPs are intentionally not part of the contract. `saw-agent` calls
`saw-integ` through Kubernetes Service DNS:

```text
https://saw-integ.<namespace>.svc.cluster.local:18083/v1
```

If the VM names change, update the Server name, Service DNS references, Route
names/hosts, and the integration TLS SANs together.

## 2. Secrets operators must provide

Never put these values in Git, cloud-init user data, PR comments, or pasted
logs.

| Secret value | Put it in | Key |
| --- | --- | --- |
| OpenAI-compatible provider key, such as GLM/LiteLLM | `saw-integ-vars` only | `integration_proxy_openai_key` |
| Internal bearer generated with `openssl rand -hex 32` | `saw-agent-vars` and `saw-integ-vars` | `inference_api_key` on `saw-agent`; `integration_proxy_expected_bearer` on `saw-integ` |
| Integration proxy CA cert | both Secrets | `integration_proxy_ca_pem` |
| Integration proxy TLS cert | `saw-integ-vars` | `integration_proxy_tls_cert_pem` |
| Integration proxy TLS private key | `saw-integ-vars` | `integration_proxy_tls_key_pem` |
| Optional Keycloak private CA | `saw-agent-vars` | `keycloak_ca_pem` |

Keycloak admin username/password are not VM runtime secrets. Use them only
out-of-band to configure the existing realm/client/users, then discard any
temporary local files.

Public/non-secret values that may appear in PR docs:

- Keycloak issuer URL, realm, public client IDs.
- OpenClaw Route origin and callback URL.
- Allowed browser usernames, for example `alice`.
- Kubernetes Service DNS names.
- Image references.

## 3. Prepare local secret payloads

Run from the repository root:

```bash
cd cloud-init

export NS='rh-vm-test1'
export ROUTE_HOST="saw-agent-openclaw.${NS}.dal.dev.cirrus.ibm.com"
export ROUTE_ORIGIN="https://${ROUTE_HOST}"
export ROUTE_CALLBACK="${ROUTE_ORIGIN}/oauth2/callback"

install -d -m 0700 .secrets
cp ansible/vars/agent-vars.example.yml .secrets/saw-agent-vars.yml
cp ansible/vars/integrations-vars.example.yml .secrets/saw-integ-vars.yml
chmod 0600 .secrets/saw-agent-vars.yml .secrets/saw-integ-vars.yml
```

Edit `.secrets/saw-agent-vars.yml`:

- replace `${NS}` with the namespace;
- set `openclaw_route_origin` to `${ROUTE_ORIGIN}`;
- set `openclaw_proxy_redirect_url` to `${ROUTE_CALLBACK}`;
- set `openclaw_proxy_allowed_users`;
- set `inference_api_key` to the internal bearer;
- set `integration_proxy_ca_pem`;
- set `keycloak_ca_pem` only if needed.

Edit `.secrets/saw-integ-vars.yml`:

- replace `${NS}` with the namespace;
- set `integration_proxy_expected_bearer` to the same internal bearer;
- set `integration_proxy_openai_key` to the provider key;
- set `integration_proxy_ca_pem`;
- set `integration_proxy_tls_cert_pem`;
- set `integration_proxy_tls_key_pem`.

For the current GLM/LiteLLM path, the integration vars should use:

```yaml
integration_proxy_upstream_url: https://ete-litellm.ai-models.vpc.res.ibm.com/v1
```

## 4. Apply OpenShift Secrets

```bash
oc -n "$NS" create secret generic saw-agent-vars \
  --from-file=vars.yml=.secrets/saw-agent-vars.yml \
  --dry-run=client -o yaml | oc apply -f -

oc -n "$NS" create secret generic saw-integ-vars \
  --from-file=vars.yml=.secrets/saw-integ-vars.yml \
  --dry-run=client -o yaml | oc apply -f -
```

Confirm shape without printing secrets:

```bash
oc -n "$NS" get secret saw-agent-vars \
  -o jsonpath='{.data.vars\.yml}' | base64 -d |
  grep -E '^(saw_vm_role|hostname|sandbox_name|inference_provider|inference_model|inference_endpoint_url):'

oc -n "$NS" get secret saw-integ-vars \
  -o jsonpath='{.data.vars\.yml}' | base64 -d |
  grep -E '^(saw_vm_role|hostname|integration_proxy_upstream_url|integration_proxy_port):'
```

## 5. Launch the VMs

Do not use broad `envsubst` against the Server manifests. The cloud-init
payload contains guest-side shell variables like `${checkout}` and
`${vars_device}`. Broad substitution can erase them and break boot.

Use namespace-only substitution:

```bash
cd cloud-init

perl -pe 's/\$\{NS\}/$ENV{NS}/g' kubernetes/integrations-server.yml | oc apply -f -
perl -pe 's/\$\{NS\}/$ENV{NS}/g' kubernetes/agent-server.yml | oc apply -f -

oc -n "$NS" wait --for=condition=Ready vmi/saw-integ --timeout=10m
oc -n "$NS" wait --for=condition=Ready vmi/saw-agent --timeout=10m
```

Create Routes after `Service/saw-agent` exists:

```bash
perl -pe 's/\$\{NS\}/$ENV{NS}/g' kubernetes/agent-userport-route.yml | oc apply -f -

oc -n "$NS" get route saw-agent-openclaw
```

## 6. Provisioning verification

On each VM, become root through the normal MFA flow and follow the provision log:

```bash
sudo su -
tail -f /var/log/saw-provision.log
```

Successful saw-integ indicators:

```bash
systemctl status saw-provision.service saw-openai-forwarder.service --no-pager -l
curl -sk https://127.0.0.1:18083/readyz
```

Expected ready response:

```json
{"status":"ready"}
```

Successful saw-agent indicators:

```bash
systemctl status saw-provision.service --no-pager -l
ss -ltnp | grep -E '18788|18789|17670' || true
curl -sS -i http://127.0.0.1:18789/ready | sed -n '1,40p'
```

Expected listeners:

- `0.0.0.0:17670`: OpenShell gateway.
- `127.0.0.1:18788`: raw OpenClaw forward.
- `*:18789`: authenticated OpenClaw proxy.

Expected OpenClaw readiness:

```text
HTTP/1.1 200 OK
...
OK
```

## 7. Model/inference verification

From saw-integ, verify the local provider proxy with the internal bearer:

```bash
INTERNAL_BEARER="$(
  awk -F= '/^INTEGRATION_PROXY_EXPECTED_BEARER=/ {print $2}' /etc/saw-integration/proxy.env
)"

curl -skS https://127.0.0.1:18083/v1/chat/completions \
  -H "Authorization: Bearer ${INTERNAL_BEARER}" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "rits/zai-org/glm-5-2-fp8",
    "messages": [{"role": "user", "content": "Reply with exactly: GLM_OK"}],
    "max_tokens": 1024
  }' | jq .

unset INTERNAL_BEARER
```

A successful response contains `GLM_OK`.

From saw-agent, verify the browser path:

```bash
curl -sS -i http://127.0.0.1:18789/ready | sed -n '1,40p'
```

Then open:

```text
https://saw-agent-openclaw.<namespace>.dal.dev.cirrus.ibm.com/
```

Sign in as an allowed Keycloak user, for example `alice`, and ask OpenClaw a
simple question. The response proves:

1. Route → saw-agent works.
2. Keycloak/OIDC auth works.
3. oauth2-proxy → local OpenClaw forward works.
4. OpenClaw → saw-integ Service DNS works.
5. saw-integ → upstream model works.

## 9. Safe rerun without recreating VMs

If cloud-init already ran and you need to consume a branch update:

```bash
cd /opt/secure-agent-workspace

curl -fsSL --retry 5 --retry-delay 5 \
  https://github.com/cooktheryan/secure-agent-workspace/archive/refs/heads/feat/openclaw-demo-alignment.tar.gz \
  | tar -xz --strip-components=1 -C /opt/secure-agent-workspace

ansible-playbook \
  -i localhost, \
  /opt/secure-agent-workspace/cloud-init/ansible/site.yml \
  -e @/etc/openshell-saw/vars.yml \
  | tee /var/log/saw-provision-rerun.log
```

This does not reboot the VM and preserves attached PVC data.

## 10. Recovery commands

If the OpenClaw user services fail on saw-agent:

```bash
uid=$(id -u openshell)

sudo -u openshell env \
  HOME=/home/openshell \
  PATH=/home/openshell/.local/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin \
  XDG_RUNTIME_DIR=/run/user/$uid \
  DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$uid/bus \
  OPENSHELL_GATEWAY=openshell-local \
  systemctl --user status \
    openclaw-sandbox.service \
    openclaw-gateway.service \
    openclaw-forward.service \
    openclaw-auth-proxy.service \
    --no-pager -l
```

If an old oauth2-proxy container is stuck:

```bash
uid=$(id -u openshell)

sudo -u openshell env \
  HOME=/home/openshell \
  XDG_RUNTIME_DIR=/run/user/$uid \
  DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$uid/bus \
  podman container cleanup openclaw-auth-proxy || true

sudo -u openshell env \
  HOME=/home/openshell \
  XDG_RUNTIME_DIR=/run/user/$uid \
  DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$uid/bus \
  podman rm -f openclaw-auth-proxy || true
```

If the OpenClaw sandbox is persisted in a non-Ready state:

```bash
uid=$(id -u openshell)

sudo -u openshell env \
  HOME=/home/openshell \
  PATH=/home/openshell/.local/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin \
  XDG_RUNTIME_DIR=/run/user/$uid \
  DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$uid/bus \
  OPENSHELL_GATEWAY=openshell-local \
  /usr/local/bin/openshell sandbox list

sudo -u openshell env \
  HOME=/home/openshell \
  PATH=/home/openshell/.local/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin \
  XDG_RUNTIME_DIR=/run/user/$uid \
  DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$uid/bus \
  OPENSHELL_GATEWAY=openshell-local \
  /usr/local/bin/openshell sandbox delete openclaw-saw || true
```

Then rerun the playbook.

## 11. Clean teardown and fresh redeploy

Delete the VM `Server` resources first. Keep or delete PVCs depending on the
test goal.

```bash
oc -n "$NS" delete server saw-agent saw-integ --ignore-not-found
oc -n "$NS" wait --for=delete vmi/saw-agent --timeout=10m || true
oc -n "$NS" wait --for=delete vmi/saw-integ --timeout=10m || true
```

For a true persistence reset, recreate these PVCs through the approved Cirrus
storage workflow:

```text
saw-agent-state-persist
saw-agent-assets-persist
saw-integ-persist
```

Then reapply the two Server manifests and Routes.

## 12. PR safety checklist

Before asking for review:

- No provider keys, bearer tokens, passwords, TLS private keys, rendered Secret
  manifests, or local `.secrets/` files are in the diff.
- `cloud-init/README.md` and this runbook match the resource names in
  `cloud-init/kubernetes/*.yml`.
- Server manifests use namespace-only substitution, not broad `envsubst`.
- `saw-integ` readiness returns `{"status":"ready"}`.
- `saw-agent` local `/ready` returns `HTTP/1.1 200 OK`.
- Browser login works through `saw-agent-openclaw`.
- A simple OpenClaw prompt reaches the configured model.
