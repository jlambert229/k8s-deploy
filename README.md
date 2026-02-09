# k8s-deploy

Deploys a [Talos Linux](https://www.talos.dev/) Kubernetes cluster on Proxmox VE using Terraform.

Uses the [`terraform-proxmox`](https://github.com/jlambert229/terraform-proxmox) module for VM provisioning and the
[siderolabs/talos](https://registry.terraform.io/providers/siderolabs/talos/latest) provider
for cluster configuration and bootstrapping.

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                    Proxmox VE                       │
│                                                     │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐          │
│  │ talos-   │  │ talos-   │  │ talos-   │          │
│  │ cp-1     │  │ w-1      │  │ w-2      │          │
│  │ .70      │  │ .80      │  │ .81      │          │
│  │ CP+etcd  │  │ worker   │  │ worker   │          │
│  └──────────┘  └──────────┘  └──────────┘          │
│       │              │              │               │
│       └──────────────┼──────────────┘               │
│              <network_cidr>                          │
└─────────────────────────────────────────────────────┘
```

## Prerequisites

| Requirement | Version |
|---|---|
| Terraform | >= 1.5 |
| Proxmox VE | 8.x or 9.x |
| API token | Created on the Proxmox host |
| Static IPs | Reserved outside your DHCP range |

## Quick start

### 1. Configure

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars — at minimum set proxmox_endpoint and proxmox_api_token
```

### 2. Deploy

```bash
terraform init
terraform plan
terraform apply
```

### 3. Get credentials

```bash
# Kubeconfig
terraform output -raw kubeconfig > ~/.kube/talos.kubeconfig
export KUBECONFIG=~/.kube/talos.kubeconfig

# Talosconfig (for talosctl)
terraform output -raw talosconfig > ~/.talos/config

# Verify
kubectl get nodes
talosctl health
```

## How it works

1. **Image download** — Talos nocloud disk image is built via the [Image Factory](https://factory.talos.dev/)
   with requested extensions (default: `qemu-guest-agent`) and downloaded to Proxmox storage.

2. **VM creation** — The `terraform-proxmox` module creates VMs with:
   - Boot disk initialized from the Talos image
   - Cloud-init config drive for network configuration (static IPs)
   - No SSH, no cloud-init user account (Talos is immutable)

3. **Config apply** — The Talos provider pushes machine configurations to each node
   via the Talos API (port 50000). Each node gets its hostname and install disk path.

4. **Bootstrap** — The first control plane node is bootstrapped, initializing etcd
   and the Kubernetes control plane. Additional nodes join automatically.

5. **Health check** — Terraform waits for all nodes to report healthy before completing.

## Default topology

| Role | Count | VM IDs | IPs | CPU | RAM | Disk |
|---|---|---|---|---|---|---|
| Control plane | 1 | 400 | .70 | 2 | 4 GB | 20 GB |
| Worker | 2 | 410-411 | .80-.81 | 2 | 4 GB | 50 GB |

## Scaling

**Add workers** — increase `worker_count`:

```hcl
worker_count = 4   # .80, .81, .82, .83
```

**HA control plane** — set 3 CPs + a VIP:

```hcl
controlplane_count = 3
cluster_vip        = "10.0.0.69"
```

## Talos extensions

The `talos_extensions` variable controls which system extensions are baked into the image.
Default: `["qemu-guest-agent"]`.

Common additions:

```hcl
talos_extensions = [
  "qemu-guest-agent",
  "iscsi-tools",        # For iSCSI storage (Longhorn, etc.)
  "util-linux-tools",   # For additional utilities
]
```

## Autoscaling

This repo includes comprehensive autoscaling for both pods and nodes:

- **HPA (Horizontal Pod Autoscaler)** - Scale pod replicas based on CPU/memory
- **VPA (Vertical Pod Autoscaler)** - Adjust pod resource requests/limits
- **Node Autoscaler** - Add/remove worker VMs based on cluster load

See **[AUTOSCALING.md](AUTOSCALING.md)** for full documentation and deployment instructions.

Quick deploy:

```bash
# Deploy pod autoscaling (HPA + VPA)
./addons/deploy-autoscaling.sh

# Enable node autoscaling (see AUTOSCALING.md)
cd addons/node-autoscaler
pip install -r requirements.txt
python autoscaler-webhook.py
```

## Upgrading Talos

1. Get the schematic ID: `terraform output talos_schematic_id`
2. Run the upgrade:
   ```bash
   talosctl upgrade \
     --image factory.talos.dev/installer/<schematic-id>:v1.9.3 \
     --preserve
   ```

## Destroying

```bash
terraform destroy
```

This removes all VMs and the downloaded Talos image from Proxmox.

## Variables

| Variable | Default | Description |
|---|---|---|
| `proxmox_endpoint` | *required* | Proxmox API URL |
| `proxmox_api_token` | *required* | API token (sensitive) |
| `proxmox_node` | `"pve"` | Target node |
| `cluster_name` | `"talos"` | Cluster name |
| `cluster_vip` | `null` | VIP for HA (set with 3 CPs) |
| `talos_version` | `"v1.9.2"` | Talos version |
| `talos_extensions` | `["qemu-guest-agent"]` | Image extensions |
| `network_cidr` | `"10.0.0.0/24"` | Network CIDR |
| `gateway` | `"10.0.0.1"` | Default gateway |
| `nameservers` | `["1.1.1.1", "8.8.8.8"]` | DNS servers |
| `controlplane_count` | `1` | Number of CPs |
| `controlplane_cpu` | `2` | CP vCPUs |
| `controlplane_memory_mb` | `4096` | CP RAM (MB) |
| `controlplane_disk_gb` | `20` | CP disk (GB) |
| `worker_count` | `2` | Number of workers |
| `worker_cpu` | `2` | Worker vCPUs |
| `worker_memory_mb` | `4096` | Worker RAM (MB) |
| `worker_disk_gb` | `50` | Worker disk (GB) |
| `vm_id_base` | `400` | Starting VM ID |
| `cp_ip_offset` | `70` | CP IP offset from network base |
| `worker_ip_offset` | `80` | Worker IP offset from network base |
| `image_storage` | `"local"` | ISO storage |
| `disk_storage` | `"local-lvm"` | Disk storage |

## Outputs

| Output | Description |
|---|---|
| `kubeconfig` | Admin kubeconfig (sensitive) |
| `talosconfig` | Talos client config (sensitive) |
| `controlplane_ips` | Map of CP name → IP |
| `worker_ips` | Map of worker name → IP |
| `cluster_endpoint` | Kubernetes API URL |
| `talos_schematic_id` | Image Factory schematic (for upgrades) |

## IP layout (defaults)

| Role | IP offset | Example (`10.0.0.0/24`) |
|---|---|---|
| Control plane | `.70` | `10.0.0.70` |
| Workers | `.80+` | `10.0.0.80`, `10.0.0.81`, ... |

IP offsets are configurable via `cp_ip_offset` and `worker_ip_offset`.
