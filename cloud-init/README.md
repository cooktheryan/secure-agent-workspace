# Cirrus cloud-init assets

GitHub Gist delivery is deprecated and unsupported for this deployment.

Cloud-init bootstrap assets must be versioned under this `cloud-init/`
directory and downloaded from a named branch or immutable commit in this
repository. Secrets must be supplied through the OpenShift Secret mounts and
must never be embedded in either the repository URL or cloud-init user data.

## Secret handling

Do not commit passwords, provider keys, bearer tokens, rendered Secret
manifests, or local operator credential files to this repository.

The two VM payload Secrets are the only places where runtime credentials enter
the deployment:

- `Secret/one-vars` receives only agent-side configuration plus the internal
  bearer used to call VM two. It must not contain a real OpenAI/provider key.
- `Secret/two-vars` receives the OpenAI/provider key, integration TLS material,
  and the internal bearer expected by the integration proxy.

Keycloak administrator credentials are not required by either VM and must not
be added to `one-vars`, `two-vars`, cloud-init user data, or Git. If an
operator needs to create or update the existing Keycloak realm/client, use
those admin credentials only from a local password manager, local ignored file,
or approved external secret store, then discard any temporary files. The
resulting public OIDC values that are safe to place in `one-vars` are the
issuer URL, realm, and public client IDs.

Before launching a VM from these assets, make sure the existing Keycloak realm
has:

- the public OpenShell CLI/dashboard client IDs referenced by `one-vars`;
- the admitted OpenClaw route callback URL registered as an allowed redirect;
- the admitted OpenClaw route origin registered as an allowed web origin; and
- the expected test/user identity, such as `alice`, with the required realm
  roles.

## Required secret inputs

An operator may need the following sensitive values. Keep them in a password
manager, an approved external secret store, or local files under an ignored
directory such as `cloud-init/.secrets/`.

| Secret value | Required where | Purpose | Commit to Git? |
| --- | --- | --- | --- |
| OpenAI/provider API key | `Secret/two-vars` only, as `integration_proxy_openai_key` | Allows VM two to call the upstream OpenAI-compatible provider | No |
| Internal bearer, 64 hex chars | Both `Secret/one-vars` as `inference_api_key` and `Secret/two-vars` as `integration_proxy_expected_bearer` | Allows VM one to call only VM two's integration proxy | No |
| Integration CA certificate | Both `Secret/one-vars` and `Secret/two-vars` as `integration_proxy_ca_pem` | Lets VM one trust VM two's HTTPS integration proxy | No, unless it is intentionally public test CA material |
| Integration TLS certificate | `Secret/two-vars` as `integration_proxy_tls_cert_pem` | Server certificate for VM two's HTTPS integration proxy | No, unless it is intentionally public test cert material |
| Integration TLS private key | `Secret/two-vars` as `integration_proxy_tls_key_pem` | Private key for VM two's HTTPS integration proxy | Never |
| Keycloak private CA certificate | `Secret/one-vars` as `keycloak_ca_pem`, only when the issuer uses private PKI | Lets VM one trust the OIDC issuer | No, unless your organization classifies that CA as public |
| Keycloak admin username/password | Local operator use only, if Keycloak client/user setup is not already complete | Configures the existing realm/client/users out-of-band | Never |

The following values are not secrets and may be documented in the PR:

- Keycloak issuer URL, realm, and public client IDs.
- OpenClaw route origin and callback URL.
- OpenClaw allowed browser identities, for example `alice`.
- The internal Service URL from VM one to VM two.

## Deployment process

The examples below assume a namespace stored in `NS`. They deliberately write
all rendered Secret material into `cloud-init/.secrets/`, which is ignored by
Git.

### 1. Select namespace and route values

```bash
cd cloud-init

export NS='rh-vm-test1'
export ROUTE_HOST="one-userport.${NS}.dal.dev.cirrus.ibm.com"
export ROUTE_ORIGIN="https://${ROUTE_HOST}"
export ROUTE_CALLBACK="${ROUTE_ORIGIN}/oauth2/callback"
```

### 2. Configure Keycloak out-of-band

Before browser login, the existing Keycloak realm/client must allow:

```text
allowed redirect URI: <ROUTE_CALLBACK>
allowed web origin:   <ROUTE_ORIGIN>
allowed user:         alice, or the value in openclaw_proxy_allowed_users
```

Use Keycloak admin credentials only in the Keycloak admin console, a local
ignored script, or an approved secret-management workflow. Do not store those
credentials in either VM Secret.

### 3. Prepare local Secret payload files

```bash
install -d -m 0700 .secrets
cp ansible/vars/one-vars.example.yml .secrets/one-vars.yml
cp ansible/vars/two-vars.example.yml .secrets/two-vars.yml
chmod 0600 .secrets/one-vars.yml .secrets/two-vars.yml
```

Edit `.secrets/one-vars.yml`:

- replace every `${NS}` with the target namespace;
- set `openclaw_route_origin` to `ROUTE_ORIGIN`;
- set `openclaw_proxy_redirect_url` to `ROUTE_CALLBACK`;
- set `openclaw_proxy_allowed_users` to the users allowed through the browser
  proxy;
- set `inference_api_key` to the generated internal bearer;
- set `integration_proxy_ca_pem` to the generated integration CA certificate;
- set `keycloak_ca_pem` only if the Keycloak issuer uses a private CA.

Edit `.secrets/two-vars.yml`:

- replace every `${NS}` with the target namespace;
- set `integration_proxy_expected_bearer` to the same internal bearer used in
  `.secrets/one-vars.yml`;
- set `integration_proxy_openai_key` to the provider API key;
- set `integration_proxy_ca_pem`, `integration_proxy_tls_cert_pem`, and
  `integration_proxy_tls_key_pem` to the generated integration TLS material.

One safe way to generate the internal bearer is:

```bash
openssl rand -hex 32
```

The integration TLS certificate must be valid for:

```text
DNS:two
DNS:two.<namespace>.svc
DNS:two.<namespace>.svc.cluster.local
IP:127.0.0.1
```

### 4. Create or update the OpenShift Secrets

```bash
oc -n "$NS" create secret generic one-vars \
  --from-file=vars.yml=.secrets/one-vars.yml \
  --dry-run=client -o yaml | oc apply -f -

oc -n "$NS" create secret generic two-vars \
  --from-file=vars.yml=.secrets/two-vars.yml \
  --dry-run=client -o yaml | oc apply -f -
```

Never commit `.secrets/one-vars.yml`, `.secrets/two-vars.yml`, or YAML rendered
from these commands.

### 5. Launch the two Cirrus Servers

```bash
perl -pe 's/\$\{NS\}/$ENV{NS}/g' kubernetes/one-server.yml | oc apply -f -
perl -pe 's/\$\{NS\}/$ENV{NS}/g' kubernetes/two-server.yml | oc apply -f -

oc -n "$NS" wait --for=condition=Ready vmi/one --timeout=10m
oc -n "$NS" wait --for=condition=Ready vmi/two --timeout=10m
```

### 6. Create the browser Route after Service one exists

The Route targets only `Service/one` port `userport`. There is intentionally
no Route to VM two.

```bash
oc -n "$NS" wait --for=jsonpath='{.metadata.name}'=one service/one --timeout=10m

oc -n "$NS" create route edge one-userport \
  --service=one \
  --port=userport \
  --hostname="$ROUTE_HOST" \
  --insecure-policy=Redirect \
  --dry-run=client -o yaml | oc apply -f -

oc -n "$NS" get route one-userport
```

### 7. Verify provisioning and access

On VM one:

```bash
tail -f /var/log/saw-provision.log
```

On VM two:

```bash
tail -f /var/log/saw-provision.log
curl -sk https://127.0.0.1:18083/readyz
```

From the operator workstation, verify the internal integration proxy through
the cluster Service:

```bash
oc -n "$NS" port-forward svc/two 28083:18083
curl -sk https://127.0.0.1:28083/readyz
```

Finally open the browser route:

```text
https://one-userport.<namespace>.dal.dev.cirrus.ibm.com/
```

Sign in as an allowed Keycloak user, then send a prompt in OpenClaw. A working
deployment reaches OpenClaw through VM one and sends model traffic from VM one
to VM two over the internal `Service/two:18083` path.

## Experimental VM two persistence

The `feat/two-persist-pvc` branch prototypes persistence for VM two only. It
expects an existing block PVC named `two-persist` in the same namespace as
`Server/two`.

During VM two cloud-init:

- the `two-persist` PVC is attached with disk serial `TWOPERSIST`;
- cloud-init leaves the persistent disk untouched so VM startup stays close to
  the known-good bootstrap path.

During VM two integration provisioning:

- the disk is formatted only when it has no filesystem;
- the disk is mounted at `/var/lib/saw-persist`;
- `/var/lib/saw-persist/etc-saw-integration` is bind-mounted to
  `/etc/saw-integration`;
- `/var/lib/saw-persist/var-lib-saw-integration` is bind-mounted to
  `/var/lib/saw-integration`.

The integration playbook then preserves any existing non-empty
`/etc/saw-integration/openai.key`. If that file is missing or zero bytes, the
playbook initializes it from `Secret/two-vars`.

This means the provider key can survive VM two recreation without allowing a
blank or placeholder value in `Secret/two-vars` to overwrite a working
persisted key. Other integration configuration, such as `proxy.env` and TLS
material, is still reconciled from `Secret/two-vars` so VM one and VM two stay
aligned when the internal bearer or certificates are intentionally rotated.
