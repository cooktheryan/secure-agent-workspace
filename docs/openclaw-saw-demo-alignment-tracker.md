# OpenClaw SAW demo alignment tracker

This file tracks the gap between this Secure Agent Workspace branch and the
`rh-forge/openclaw-saw-demo` deployment flow. Keep it boring and current:
when a step is verified, check it off or remove it, then commit the update.

## Source refresh

- Upstream reference checkout: `/Users/rcook/git/openclaw-saw-demo`
- Refreshed from `origin/main`: 2026-08-21
- Upstream commit inspected: `562bd25` (`forwarder files`)
- Source files reviewed:
  - `README.md`
  - `docs/components-and-images.md`
  - `docs/credentials.md`

## Already aligned and verified in this branch

- [x] Use demo VM names:
  - `saw-agent`
  - `saw-integ`
- [x] Use demo-facing route name/host pattern:
  - `saw-agent-userport`
- [x] Use persistent disk names selected for this environment:
  - `saw-agent-state-persist`
  - `saw-agent-assets-persist`
  - `saw-integ-persist`
- [x] Use OpenClaw sandbox name `openclaw-saw`.
- [x] Mount persistent OpenClaw state/assets so identity, soul, workspace, and
  sessions survive reboot.
- [x] Keep provider credentials out of the agent VM and route inference through
  the integration VM.
- [x] Configure GLM as the default OpenAI-compatible inference backend:
  - provider label: `glm`
  - model: `rits/zai-org/glm-5-2-fp8`
  - upstream: `https://ete-litellm.ai-models.vpc.res.ibm.com/v1`
- [x] Store the GLM token in the OpenShift secret for `saw-integ`; do not commit
  the token.
- [x] Keep the OpenClaw browser route protected by the existing authenticated
  proxy/trusted-proxy setup.
- [x] Validate the live OpenClaw UI after the name-change and GLM migration.

## Demo requirements still left to implement

### Six credential-isolating integration proxies

The upstream demo expects these to live on `saw-integ`, with real service
credentials staying on the integration VM side of the boundary.

- [ ] Gmail read proxy
  - image: `${IMAGE_REPOSITORY}/gmail-read-proxy:latest`
  - source: `rh-forge/rust-gmail-proxy/read-proxy`
  - credential material: read-only Gmail OAuth grant
  - validation: proxy ready, OpenClaw can read through the governed path
- [ ] Gmail write proxy
  - image: `${IMAGE_REPOSITORY}/gmail-write-proxy:latest`
  - source: `rh-forge/rust-gmail-proxy/write-proxy`
  - credential material: compose-only Gmail OAuth grant
  - validation: write path can create draft/proposal without granting broad mail
    access to OpenClaw
- [ ] Microsoft 365 read proxy
  - image: `${IMAGE_REPOSITORY}/m365-read-proxy:latest`
  - source: `rh-forge/rust-m365-proxy/read-proxy`
  - credential material: delegated read OAuth grant
  - validation: read proxy ready and scoped Graph read request works
- [ ] Microsoft 365 write proxy
  - image: `${IMAGE_REPOSITORY}/m365-write-proxy:latest`
  - source: `rh-forge/rust-m365-proxy/write-proxy`
  - credential material: delegated write OAuth grant
  - validation: draft/send proposal flow works through the write boundary
- [ ] Slack read proxy
  - image: `${IMAGE_REPOSITORY}/slack-read-proxy:latest`
  - source: `rh-forge/rust-slack-proxy`
  - credential material: read-scoped Slack user token
  - validation: read proxy ready and scoped Slack read request works
- [ ] Slack write proxy
  - image: `${IMAGE_REPOSITORY}/slack-write-proxy:latest`
  - source: `rh-forge/rust-slack-proxy`
  - credential material: write-scoped Slack user token
  - validation: approval/front-door write path works without attaching write
    authority directly to OpenClaw

### OpenClaw runtime and image alignment

- [ ] Pin the OpenClaw runtime/image to demo version `2026.8.1-beta.2`.
  - Current status: intentionally deferred. Earlier image/version work made the
    deployment unstable, so do this only as a separate tested checkpoint.
  - Validation gate: deploy fresh `saw-agent`, confirm `/ready`, login as
    `alice`, and complete one successful LLM request before committing.
- [ ] Confirm whether all seven runtime images are already published under the
  expected repository before adding build steps:
  - OpenClaw headless CSB
  - Gmail read proxy
  - Gmail write proxy
  - M365 read proxy
  - M365 write proxy
  - Slack read proxy
  - Slack write proxy
- [ ] Avoid adding VM-time image builds unless a required published image is
  unavailable. The upstream demo assumes published runtime images; building
  during cloud-init made earlier tests slower and more fragile.

### OpenClaw/provider registration work

- [ ] Add provider definitions for each read proxy in the agent-side OpenClaw
  configuration.
- [ ] Add only the intended write front-door capability for write flows; do not
  attach broad write credentials directly to the agent sandbox.
- [ ] Add per-proxy health/readiness checks to provisioning.
- [ ] Add failure diagnostics that print proxy status/log tails without printing
  secrets.
- [ ] Add tests that reject stale legacy names (`one`, `two`, `sawone`) in
  active manifests, vars, and rendered config.

### Daily briefing / Chief of Staff package

The upstream README includes temporary PoC scaffolding for installing the daily
briefing identity, instructions, schema, and skill from `rh-forge/forge-agent-catalog`.

- [ ] Decide whether this branch should install the daily briefing package.
- [ ] If yes, add a non-secret user profile contract:
  - display name
  - role
  - initials
  - email
  - time zone
- [ ] Persist the installed package under the OpenClaw persistent workspace.
- [ ] Track the installed `forge-agent-catalog` commit for reproducibility.
- [ ] Replace the temporary installer once OpenClaw exposes the supported Claw
  package installation command.

### Forge UI and relay

The upstream demo includes Forge UI and relay as a later access path. Those
images are built inside OpenShift, not pulled from Quay.

- [ ] Decide whether Forge UI/relay belongs in this SAW branch or stays in the
  demo repo.
- [ ] If included, add build/deploy flow for:
  - `rh-forge-ui`
  - `rh-forge-ui-relay`
- [ ] Store the OpenClaw gateway token in the relay Secret without printing it.
- [ ] Add route validation for the Forge UI.
- [ ] Document that the PoC demo header injector is not a production
  authentication boundary.

## Suggested implementation order

1. Keep the current GLM/name-change baseline as the rollback point.
2. Add one read-only proxy first, preferably Gmail read.
3. Deploy fresh VMs and validate:
   - integration proxy ready endpoint
   - agent ready endpoint
   - OpenClaw UI login as `alice`
   - one LLM request
   - one proxy-backed tool request
4. Commit the healthy checkpoint.
5. Add the paired write proxy for the same provider and repeat the full
   validation gate.
6. Repeat for M365 read/write, then Slack read/write.
7. Only after the proxy topology is stable, revisit the OpenClaw
   `2026.8.1-beta.2` image/version pin.
8. Decide on daily briefing and Forge UI as separate checkpoints.

## Validation gate for every checked item

Before checking off or removing an item:

- [ ] No secret value appears in Git diff, logs, or copied command output.
- [ ] `saw-integ` health/readiness succeeds for the relevant service.
- [ ] `saw-agent` OpenClaw route is reachable.
- [ ] Browser login as `alice` succeeds.
- [ ] OpenClaw can complete a basic LLM response.
- [ ] The new integration/tool path works at least once.
- [ ] Fresh deployment or reboot behavior is understood and documented.
- [ ] A commit records the healthy checkpoint.

## Operational notes

- When rendering Kubernetes manifests with shell variables embedded in
  cloud-init, use namespace-only substitution:

  ```bash
  envsubst '${NS}' < input.yml | oc apply -f -
  ```

  Do not use broad `envsubst`; it can erase cloud-init shell variables such as
  `${vars_device}` and `${checkout}`.

- Keep provider secrets in OpenShift Secrets or on the integration VM. Do not
  commit OAuth tokens, API keys, refresh tokens, front-door bearers, or gateway
  tokens.
- The current GLM implementation still uses some OpenAI-compatible naming
  (`OPENAI_*`, `openai_forwarder.py`) because the proxy speaks the OpenAI API
  shape. Provider-neutral naming can be cleaned up later, but should not block
  the functional proxy work.
