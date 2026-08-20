# kind VM

A Cirrus/KubeVirt VM (the Cirrus `Server` is named **`kind`**) in OpenShift
namespace `rh-vm-test1` that runs a [kind](https://kind.sigs.k8s.io/)
(Kubernetes-in-podman) single-node cluster, installed entirely by cloud-init. It
hosts applications (e.g. HashiCorp Vault) and exposes them so **other VMs in the
same Cirrus/OpenShift environment** can consume them through a Kubernetes
Service, reachable at `kind:<port>`.

> **Why kind and not MicroShift — repository access.** This is deliberately a
> **kind** cluster, not MicroShift. MicroShift ships only in the `rhocp` +
> `fast-datapath` subscription repositories, and this VM cannot reach them: it is
> bound to IBM's internal Satellite (org `CPC`), which serves BaseOS/AppStream
> but **not** `rhocp`, and a console.redhat.com activation key can't authenticate
> against IBM's Satellite. Without access to those repositories MicroShift is not
> installable here. kind needs only `podman` (from AppStream) and pulls its node
> image from public Docker Hub — no subscription, no pull secret, no `rhocp`
> access required.

## How exposure works (two layers)

```
app pod (kind)
  -> NodePort Service                     (kind node listens on :30820)
    -> kind extraPortMapping              (VM OS :30820 -> node :30820)
      -> Cirrus Server.spec.ports         (declares :30820)
        -> OpenShift Service "kind" (created by the Cirrus operator)
          -> other VMs reach the app at kind:30820
```

A NodePort must be **port-mapped by kind** (via `extraPortMappings` in
`/etc/kind/cluster.yaml`) to reach the VM's network, then declared in
`server.yaml`. Port `30820` is pre-wired end to end.

Ports wired at boot:

| Cirrus port | Purpose |
| --- | --- |
| `api` / `6443` | kube-apiserver (kind binds `0.0.0.0:6443`) |
| `vault` / `30820` | Pre-wired NodePort → kind extraPortMapping for a Vault-class app |

To expose an **additional** NodePort you must both add an `extraPortMappings`
entry to `/etc/kind/cluster.yaml` **and** a `server.yaml` port — and kind only
reads port mappings at cluster-create time, so the cluster must be recreated for
a new port. Pick your ports up front.

## Persistence

**Ephemeral.** The VMI root disk resets on restart and the kind cluster is
recreated from scratch by cloud-init, so **all cluster state is lost on restart**
— not yet safe for real Vault data. This account cannot create PVCs; durable
storage needs an admin to provision one (see `pvc.yaml`) which would then be
mounted and pointed at podman's storage / a hostPath-backed PV.

## Deploy

Prerequisites:

- `oc` logged into the target cluster; the `cirrus.ibm.com/v1alpha1` `Server`
  CRD + Cirrus operator installed; the target namespace exists.
- **Edit the environment-specific values first** — these are placeholders for the
  author's environment and will not exist in yours:
  - `server.yaml` / `pvc.yaml`: `namespace` (default `rh-vm-test1`)
  - `server.yaml`: `spec.containerDiskImage` (a RHEL 9 golden image in your registry)
  - `pvc.yaml`: `storageClassName` (a Block-capable class in your cluster)
  - scripts honor `NS=<namespace>` to override the namespace at runtime.

```bash
cd hacks
oc apply --dry-run=server -f server.yaml   # validate first
./apply.sh                                 # creates the cloud-init Secret + Server
```

`apply.sh` creates the `kind-cloudinit` Secret from `cloudinit.userdata`,
then applies the Server. No subscription or pull-secret setup is required.

To pick up a changed `cloudinit.userdata` on the running VM, re-run `apply.sh`
then recreate the VMI (`oc delete vmi kind -n rh-vm-test1`) — the VM
controller recreates it and cloud-init reruns on the fresh disk.

## Watch first-boot provisioning

Human SSH is via Cirrus MFA. On the VM:

```bash
sudo tail -f /var/log/cloud-init-output.log   # dnf podman -> kind download -> create cluster
export KIND_EXPERIMENTAL_PROVIDER=podman
sudo -E kind get clusters                     # expect: kind
```

## Use the cluster

cloud-init writes kubeconfigs for `cloud-user`:

- `~cloud-user/.kube/config` — server `https://0.0.0.0:6443` (for use **on the VM**)
- `~cloud-user/kubeconfig` — same, but server rewritten to the VM IP (for use
  **from other hosts**)

On the VM:

```bash
kubectl get nodes        # expect one control-plane node, Ready
kubectl get pods -A
```

Retrieve it to your workstation:

```bash
virtctl scp --namespace rh-vm-test1 \
  cloud-user@vmi/kind:kubeconfig ./kind-kubeconfig
export KUBECONFIG=$PWD/kind-kubeconfig
kubectl --insecure-skip-tls-verify get nodes
```

> The kind API server cert does **not** include the VM IP as a SAN, so remote
> `kubectl` needs `--insecure-skip-tls-verify` (or add the IP to the cluster's
> cert SANs). Cross-VM access to *apps* uses the NodePort path below, which is
> unaffected.

## Deploy Vault and expose it to other VMs

1. Deploy Vault into the cluster (Helm or manifests). For a **first-pass proof**
   use ephemeral storage.
2. Create a NodePort Service pinned to the pre-wired port so it lines up with
   both the kind port mapping and `server.yaml`:

   ```yaml
   apiVersion: v1
   kind: Service
   metadata:
     name: vault-nodeport
     namespace: vault
   spec:
     type: NodePort
     selector:
       app.kubernetes.io/name: vault
     ports:
       - name: http
         port: 8200
         targetPort: 8200
         nodePort: 30820   # matches kind extraPortMapping + server.yaml 'vault'
   ```

3. From another VM in `rh-vm-test1`, reach Vault at **`kind:30820`**
   (OpenShift Service → VM:30820 → kind port mapping → NodePort).

## Validation

`./verify.sh` runs the full suite. **Layer 1** (Cirrus Server, VMI, Service,
ports, cloud-init Secret) runs from the workstation via `oc`. **Layer 2** (in-VM
kind health) needs `virtctl ssh`, which is **not permitted for this account** —
access is Cirrus MFA only — so it degrades to a WARN and you run the in-VM checks
yourself in your MFA SSH session:

```bash
export KIND_EXPERIMENTAL_PROVIDER=podman
sudo -E kind get clusters                       # expect: kind
kubectl get nodes                               # expect: Ready
kubectl get pods -A                             # expect: all Running
lsblk --nodeps -no name,serial | grep -qw MSDATA1 && echo "persistent disk" || echo "EPHEMERAL"
```

If `verify.sh` runs from a context where `virtctl ssh` *is* allowed, Layer 2
runs automatically. Set `FROM_VM=<other-vm>` to also test that another VM can
reach the `vault` NodePort (`kind:30820`).

## Recovery checks

```bash
oc get server,vm,vmi,service -n rh-vm-test1
oc get svc kind -n rh-vm-test1 -o wide
```
