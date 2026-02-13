# k8s-deploy

![pre-commit](https://github.com/jlambert229/k8s-deploy/actions/workflows/pre-commit.yml/badge.svg)
![GitHub last commit](https://img.shields.io/github/last-commit/jlambert229/k8s-deploy)

Deploy a [Talos Linux](https://www.talos.dev/) Kubernetes cluster on libvirt/KVM using Terraform.

Uses [terraform-libvirt](https://github.com/jlambert229/terraform-libvirt) for VM provisioning (with cloud-init for initial networking) and the [Talos Terraform provider](https://registry.terraform.io/providers/siderolabs/talos/latest) for cluster orchestration.

## Architecture

```
┌─────────────────────────────────────────────┐
│  KVM Host                                   │
│                                             │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐    │
│  │ talos-cp-1│ │ talos-w-1│ │ talos-w-2│    │
│  │  (CP)     │ │ (Worker) │ │ (Worker) │    │
│  └────┬─────┘ └────┬─────┘ └────┬─────┘    │
│       │             │            │           │
│  ─────┴─────────────┴────────────┴──── br0  │
└─────────────────────────────────────────────┘
```

Terraform creates VMs from a Talos disk image (CoW clones), assigns static IPs via cloud-init, then configures and bootstraps the cluster through the Talos API.

## Prerequisites

- **KVM host** with `qemu-kvm`, `libvirt-daemon-system`, `virtinst`, `cloud-image-utils` (for `cloud-localds`)
- **OVMF firmware** (`ovmf` package) for UEFI boot
- **Bridge interface** (e.g., `br0`) on the host
- **Storage pool** configured in libvirt (default: `default`)
- **Terraform** >= 1.5.0 (project uses 1.14.4 — `tenv tf install`)

## Quick Start

### 1. Download the Talos Image

First, run a targeted plan to get the image factory URL:

```bash
tfinit
tfp -target=talos_image_factory_schematic.this
```

Then download and decompress the image to the KVM host's storage pool:

```bash
# The URL includes your configured extensions (e.g., qemu-guest-agent)
wget -O- "https://factory.talos.dev/image/<schematic-id>/v1.9.2/nocloud-amd64.raw.xz" \
  | xz -d > /var/lib/libvirt/images/talos-v1.9.2-nocloud.raw
```

Or use the output after the first apply:

```bash
terraform output -raw talos_image_url
```

### 2. Configure Variables

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
```

Key settings to customize:

- `talos_image_path` — path to the downloaded Talos image
- `libvirt_uri` — `qemu:///system` (run on host) or `qemu+ssh://user@host/system` (run remotely)
- `cloudinit_iso_dir` — where cloud-init ISOs live (default `/data/libvirt/images`)
- `network_cidr`, `gateway` — your network
- `controlplane_count`, `worker_count` — cluster size
- `cluster_vip` — set this for HA (3 CP nodes)

### 3. Deploy

```bash
tfinit
tfp    # review the plan
tfa    # apply (requires confirmation)
```

Terraform will:

1. Create VMs (CoW clones from the Talos image)
2. Attach cloud-init ISOs with static network config (IP, gateway, DNS)
3. Generate Talos machine secrets and configs
4. Apply machine configs to each node (hostname, install disk, VIP)
5. Bootstrap the first control plane node
6. Wait for cluster health check
7. Write `kubeconfig` and `talosconfig` to `generated/`

### 4. Access the Cluster

```bash
# Kubernetes
export KUBECONFIG=$(pwd)/generated/kubeconfig
kubectl get nodes

# Talos
export TALOSCONFIG=$(pwd)/generated/talosconfig
talosctl health
```

## Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `libvirt_uri` | `qemu:///system` | Libvirt connection URI |
| `cluster_name` | `talos` | Cluster name (used in VM names) |
| `cluster_vip` | `null` | VIP for HA control plane |
| `talos_version` | `v1.9.2` | Talos Linux version |
| `talos_extensions` | `["qemu-guest-agent"]` | System extensions |
| `talos_image_path` | *(required)* | Path to Talos image on KVM host |
| `talos_image_format` | `raw` | Image format (`raw` or `qcow2`) |
| `install_disk` | `/dev/vda` | Talos install disk (virtio) |
| `network_bridge` | `br0` | Host bridge interface |
| `network_cidr` | `10.0.0.0/24` | Network CIDR |
| `gateway` | `10.0.0.1` | Default gateway |
| `nameservers` | `["1.1.1.1", "8.8.8.8"]` | DNS servers |
| `storage_pool` | `default` | Libvirt storage pool |
| `cloudinit_iso_dir` | `/data/libvirt/images` | Directory for cloud-init ISOs on host |
| `controlplane_count` | `1` | CP nodes (1 or 3) |
| `controlplane_cpu` | `2` | vCPUs per CP |
| `controlplane_memory` | `4096` | MiB per CP |
| `controlplane_disk` | `20` | GiB per CP |
| `worker_count` | `2` | Worker nodes |
| `worker_cpu` | `2` | vCPUs per worker |
| `worker_memory` | `4096` | MiB per worker |
| `worker_disk` | `50` | GiB per worker |
| `cp_ip_offset` | `70` | CP IP offset from CIDR |
| `worker_ip_offset` | `80` | Worker IP offset from CIDR |
| `uefi` | `true` | UEFI boot |
| `nfs_server` | `null` | NFS server IP (enables CSI driver) |
| `nfs_appdata_share` | `/volume1/nfs01/k8s-appdata` | NFS share for PVCs |

**Libvirt connection:**

- `qemu:///system` — Run Terraform on the KVM host. Cloud-init ISOs are created locally.
- `qemu+ssh://user@host/system` — Run Terraform from your workstation. Cloud-init ISOs are streamed over SSH to the host.

## Outputs

| Output | Description |
|--------|-------------|
| `kubeconfig` | Kubernetes admin kubeconfig (sensitive) |
| `talosconfig` | Talos client configuration (sensitive) |
| `cluster_endpoint` | Kubernetes API endpoint URL |
| `controlplane_ips` | CP node name → IP mapping |
| `worker_ips` | Worker node name → IP mapping |
| `talos_schematic_id` | Image factory schematic (for upgrades) |
| `talos_image_url` | Download URL for the Talos image |

## Networking

VMs use **bridge networking** — they connect directly to the host's bridge interface and appear as peers on the physical network.

**How IP assignment works:**

1. Each VM gets a **deterministic MAC address** (QEMU OUI `52:54:00`)
2. A **cloud-init ISO** is attached with static network config (NoCloud datasource)
3. Talos reads the cloud-init network config on first boot and configures the static IP
4. The Talos API becomes reachable at the static IP in maintenance mode
5. Terraform applies the full machine config via the Talos API

No DHCP reservations are needed — cloud-init handles initial IP assignment, just like the Proxmox cloud-init approach.

**HA with VIP:** Set `cluster_vip` and use 3 CP nodes. Talos manages the VIP using VRRP — one CP node holds the VIP at any time, and it floats to a healthy peer on failure.

**Health check:** Terraform waits for cluster health before writing kubeconfig/talosconfig and installing NFS. If the health check times out (e.g. qemu-guest-agent keeps nodes in "booting" without a virtio-serial channel), set `talos_extensions = []` to remove the extension.

## Upgrades

To upgrade Talos:

1. Update `talos_version` in your tfvars
2. Download the new image (check `terraform output talos_image_url`)
3. Update `talos_image_path` if the filename changed
4. `terraform apply`

The schematic ID is tracked as an output for use with `talosctl upgrade`.
