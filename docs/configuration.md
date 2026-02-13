# Configuration Reference

→ [Architecture](architecture.md) · [Operations](operations.md) · [README](../README.md)

Variables are grouped by concern. Most have sensible defaults; focus on the essentials.

> **Essential:** `talos_image_path`, `libvirt_uri`, `network_cidr`, `gateway`

---

## Variable Groups

### Libvirt

| Variable | Default | Description |
|----------|---------|-------------|
| `libvirt_uri` | `qemu:///system` | Connection URI |

**Connection modes:**

- **`qemu:///system`** — Terraform runs on the KVM host. Cloud-init ISOs created locally.
- **`qemu+ssh://user@host/system`** — Terraform runs remotely. Cloud-init streamed over SSH.

---

### Cluster

| Variable | Default | Description |
|----------|---------|-------------|
| `cluster_name` | `talos` | Cluster and VM naming prefix |
| `cluster_vip` | `null` | Virtual IP for HA (use with 3 CP nodes) |

---

### Talos

| Variable | Default | Description |
|----------|---------|-------------|
| `talos_version` | `v1.9.2` | Talos Linux version |
| `talos_extensions` | `["qemu-guest-agent"]` | Image factory extensions |
| `talos_factory_url` | `https://factory.talos.dev` | Image factory base URL |
| `talos_image_path` | *(required)* | Path to disk image on KVM host |
| `talos_image_format` | `raw` | `raw` or `qcow2` |
| `install_disk` | `/dev/vda` | Talos install target (virtio) |

---

### Network

| Variable | Default | Description |
|----------|---------|-------------|
| `network_bridge` | `br0` | Host bridge interface |
| `network_cidr` | `10.0.0.0/24` | CIDR for node IPs |
| `gateway` | `10.0.0.1` | Default gateway |
| `nameservers` | `["1.1.1.1", "8.8.8.8"]` | DNS servers |

---

### Storage

| Variable | Default | Description |
|----------|---------|-------------|
| `storage_pool` | `default` | Libvirt storage pool |
| `cloudinit_iso_dir` | `/data/libvirt/images` | Directory for cloud-init ISOs |

---

### Control Plane

| Variable | Default | Description |
|----------|---------|-------------|
| `controlplane_count` | `1` | CP nodes (1 or 3) |
| `controlplane_cpu` | `2` | vCPUs |
| `controlplane_memory` | `4096` | MiB |
| `controlplane_disk` | `20` | GiB |

---

### Workers

| Variable | Default | Description |
|----------|---------|-------------|
| `worker_count` | `2` | Worker count |
| `worker_cpu` | `2` | vCPUs |
| `worker_memory` | `4096` | MiB |
| `worker_disk` | `50` | GiB |

---

### IP Offsets

IPs = `cidrhost(network_cidr, offset + index)`.

| Variable | Default | Example (10.0.0.0/24) |
|----------|---------|------------------------|
| `cp_ip_offset` | `70` | .70, .71, .72 |
| `worker_ip_offset` | `80` | .80, .81 |

---

### Boot

| Variable | Default | Description |
|----------|---------|-------------|
| `uefi` | `true` | UEFI boot (recommended) |

---

### NFS Storage (Optional)

| Variable | Default | Description |
|----------|---------|-------------|
| `nfs_server` | `null` | NFS server IP (enables CSI) |
| `nfs_appdata_share` | `/volume1/nfs01/k8s-appdata` | Share path |
| `nfs_csi_version` | `v4.9.0` | CSI driver chart version |

---

## Outputs

| Output | Description |
|--------|-------------|
| `kubeconfig` | Kubernetes admin kubeconfig (sensitive) |
| `talosconfig` | Talos client config (sensitive) |
| `kubernetes_client_configuration` | K8s API credentials (sensitive) |
| `cluster_endpoint` | API URL (`https://...:6443`) |
| `controlplane_ips` | CP name → IP |
| `worker_ips` | Worker name → IP |
| `talos_schematic_id` | Image schematic (for upgrades) |
| `talos_image_url` | Factory download URL |
