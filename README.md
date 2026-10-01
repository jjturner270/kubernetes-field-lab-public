# Kubernetes Field Lab — Hetzner

A reproducible, disposable Kubernetes cluster built from raw Linux servers.

```text
Terraform
   ↓
Hetzner Cloud
   ├─ control-01
   ├─ worker-01
   └─ worker-02
   ↓
Ansible
   ↓
Ubuntu + containerd + kubeadm
   ↓
Kubernetes
   ↓
Cilium
   ↓
demo workload
   ↓
verification + evidence
```

The point of this repo is not "I can click Create Cluster."

The point is:

> Give me cloud credentials and Linux machines; I can provision the infrastructure,
> configure the hosts, bootstrap Kubernetes, deploy a workload, verify the resulting
> state, deliberately break a node, recover it, and destroy the entire environment.

## What it builds

- 1 Kubernetes control-plane node
- 2 Kubernetes worker nodes
- Hetzner private network: `10.10.0.0/16`
- Cloud firewall
- Ubuntu 24.04
- containerd
- kubeadm / kubelet / kubectl
- Cilium CNI
- 3-replica demo workload
- verification/evidence capture
- deliberate kubelet failure + recovery

## Requirements on your workstation

- Terraform
- Ansible
- kubectl
- OpenSSH client
- curl
- jq
- a Hetzner Cloud project/API token
- an SSH key at `~/.ssh/id_ed25519` (or override the path)

Ubuntu/WSL quick setup:

```bash
sudo apt update
sudo apt install -y ansible curl jq openssh-client unzip

# kubectl
sudo snap install kubectl --classic

# Terraform: install using HashiCorp's package instructions
# https://developer.hashicorp.com/terraform/install
```

Create an SSH key if you do not already have one:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519
```

## 1. Create a Hetzner API token

In your Hetzner Cloud project:

**Security → API Tokens → Generate API Token → Read & Write**

Then:

```bash
export HCLOUD_TOKEN='YOUR_TOKEN'
```

Do **not** commit the token.

Do **not** commit the token. Runtime files such as `terraform.tfstate`, `terraform.tfvars`, `.kube/`, generated inventory, and verification evidence are ignored by Git. The Terraform provider lockfile is intentionally committed for reproducible provider selection.

## 2. Restrict access to your current public IP

The Terraform firewall requires your workstation's public IPv4 CIDR.

```bash
export TF_VAR_admin_cidr="$(curl -4 -s https://ifconfig.me)/32"
echo "$TF_VAR_admin_cidr"
```

Example:

```text
203.0.113.44/32
```

## 3. Provision everything

From the repo:

```bash
make infra
```

Terraform creates:

```text
control-01  10.10.0.10
worker-01   10.10.0.11
worker-02   10.10.0.12
```

Each server also has a public IPv4 address for workstation SSH access.

## 4. Generate Ansible inventory

```bash
make inventory   # generates inventory and enrolls SSH host keys
```

Inspect it:

```bash
cat ansible/inventory.ini
```

Then prove SSH + Ansible connectivity:

```bash
make ping
```

Expected shape:

```text
control-01 | SUCCESS => {
    "ping": "pong"
}
worker-01 | SUCCESS => {
    "ping": "pong"
}
worker-02 | SUCCESS => {
    "ping": "pong"
}
```

## 5. Build Kubernetes

```bash
make cluster
```

That performs:

```text
all nodes
  ├─ configure Hetzner private NIC / static private IP
  ├─ verify private-network reachability
  ├─ disable swap
  ├─ load kernel modules
  ├─ configure forwarding/bridge sysctls
  ├─ install containerd
  ├─ configure systemd cgroups
  ├─ install kubelet/kubeadm/kubectl
  └─ bind kubelet to private node IP

control-01
  ├─ kubeadm init
  ├─ install Cilium
  ├─ wait for Cilium
  └─ create worker join command

workers
  └─ kubeadm join

workstation
  └─ fetch kubeconfig
```

The local kubeconfig is written to:

```text
.kube/config
```

Use it with:

```bash
export KUBECONFIG="$PWD/.kube/config"
kubectl get nodes -o wide
```

## 6. Deploy the workload

```bash
make deploy
```

Then:

```bash
export KUBECONFIG="$PWD/.kube/config"
kubectl get pods -n field-lab -o wide
```

## 7. Produce evidence

```bash
make verify
```

Evidence is written to:

```text
evidence/
├── timestamp.txt
├── nodes.txt
├── pods.txt
├── system-pods.txt
├── cluster-info.txt
├── cilium.txt
├── dns.txt
└── app.txt
```

Successful verification ends with:

```text
RESULT: CLUSTER HEALTHY
```

## 8. Break a worker

```bash
make break
```

This deliberately stops kubelet on `worker-01`.

Watch the cluster:

```bash
export KUBECONFIG="$PWD/.kube/config"
kubectl get nodes -w
```

In another terminal:

```bash
kubectl get pods -n field-lab -o wide -w
```

## 9. Recover it

```bash
make recover
make verify
```

That restarts kubelet and verifies the cluster from observed state.

## 10. Destroy everything

Do not leave the lab running when you are done:

```bash
make destroy
```

## One-shot happy path

```bash
export HCLOUD_TOKEN='...'
export TF_VAR_admin_cidr="$(curl -4 -s https://ifconfig.me)/32"

make infra
make inventory   # also enrolls fresh SSH host keys
make ping
make cluster
make deploy
make verify
```

Then:

```bash
make break
make recover
make verify
make destroy
```

## Useful commands

```bash
make help
make ips
make ssh-control
make nodes
make pods
make evidence
```

## Design notes

The Kubernetes API is initialized on the control plane's private Hetzner address. The
public control-plane IP is included as an API server certificate SAN so the fetched
workstation kubeconfig can safely address the cluster from outside the private network.

The firewall allows:

- SSH from `admin_cidr`
- Kubernetes API from `admin_cidr`
- node-to-node traffic from the private `10.10.0.0/16` network
- ICMP from `admin_cidr`

Change `admin_cidr` if your public IP changes.

## Versions

Defaults live in `ansible/group_vars/all.yml`.

The lab currently targets:

- Ubuntu 24.04
- Kubernetes 1.34 package repository
- Cilium 1.20.2

These are deliberately visible variables rather than hidden installer behavior.

## Resume-sized description

> Automated provisioning of a three-node Kubernetes environment on Hetzner Cloud
> using Terraform and Ansible, including private networking, firewall policy,
> containerd/kubeadm bootstrap, Cilium networking, workload deployment, automated
> health verification, deliberate node failure, recovery testing, and complete
> infrastructure teardown.
