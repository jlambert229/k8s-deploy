# Architecture

How k8s-deploy creates a Talos Kubernetes cluster on libvirt/KVM. From Terraform config to a ready Kubernetes API in one apply.

→ [Configuration reference](configuration.md) · [Operations](operations.md) · [README](../README.md)

---

## Overview

```mermaid
flowchart TB
    subgraph Workstation["Your Workstation"]
        TF[Terraform apply]
        TALOS[Talos Provider]
        TF --> TALOS
    end

    subgraph KVM["KVM Host"]
        subgraph Libvirt["libvirt"]
            VMS[VMs<br/>Talos disk + cloud-init ISO]
        end
        subgraph Nodes["Cluster Nodes"]
            CP1[talos-cp-1]
            W1[talos-w-1]
            W2[talos-w-2]
        end
        VMS --> Nodes
    end

    TF <-.->|"qemu+ssh or qemu:///"| Libvirt
    TALOS <-->|"Talos API<br/>static IPs"| Nodes
```

## Cluster Topology

*Default: 1 control plane, 2 workers. All nodes on the host bridge.*

```mermaid
flowchart TB
    subgraph Host["KVM Host"]
        subgraph br0["bridge br0"]
            CP["talos-cp-1<br/>10.0.0.70 · Control Plane"]
            W1["talos-w-1<br/>10.0.0.80"]
            W2["talos-w-2<br/>10.0.0.81"]
        end
    end

    CP <-->|"etcd · API"| W1 & W2
    CP -->|"kubectl"| Client["Your workstation"]
```

*HA: 3 control planes + VIP. One CP holds the floating VIP via VRRP.*

---

```mermaid
flowchart TB
    subgraph Host["KVM Host · br0"]
        subgraph CPs["Control Plane"]
            CP1["talos-cp-1<br/>.70"]
            CP2["talos-cp-2<br/>.71"]
            CP3["talos-cp-3<br/>.72"]
        end
        VIP["cluster_vip<br/>10.0.0.100"]
        W1["talos-w-1"]
        W2["talos-w-2"]
    end

    CP1 -.->|"VRRP (active)"| VIP
    CP2 & CP3 -.->|"VRRP (standby)"| VIP
    VIP -->|"Kubernetes API"| Client["kubectl"]
```

## Deploy Flow

```mermaid
sequenceDiagram
    autonumber
    participant T as Terraform
    participant S as create-cloudinit-iso.sh
    participant KVM as KVM Host
    participant Talos as Talos API

    rect rgb(240, 248, 255)
        Note over T,Talos: Phase 1 — Prepare
        T->>T: Generate machine secrets & configs
        T->>S: Render templates (user-data, meta-data, network-config)
        alt Remote (qemu+ssh)
            S->>KVM: Stream tarball over SSH
            KVM->>KVM: cloud-localds → ISO
        else Local (qemu:///system)
            S->>S: cloud-localds locally
        end
    end

    rect rgb(240, 255, 240)
        Note over T,Talos: Phase 2 — VMs
        T->>KVM: Create VMs (CoW clones + cloud-init ISO)
        KVM->>Talos: VMs boot, Talos reads network-config
        Talos->>Talos: Static IP assigned
    end

    rect rgb(255, 250, 240)
        Note over T,Talos: Phase 3 — Bootstrap
        T->>Talos: Apply full machine config
        T->>Talos: Bootstrap first CP
        T->>T: Health check (15m timeout)
    end

    rect rgb(248, 248, 255)
        Note over T,Talos: Phase 4 — Done
        T->>T: Write kubeconfig, talosconfig
        T->>T: Install NFS CSI (if nfs_server set)
    end
```

## Component Stack

```mermaid
flowchart TB
    subgraph Outputs["Outputs"]
        KUBE[kubeconfig]
        TALOSCFG[talosconfig]
    end

    subgraph PostBootstrap["Post-bootstrap"]
        NFS[NFS CSI · StorageClass]
    end

    subgraph Bootstrap["Bootstrap"]
        ETCD[etcd + Kubernetes]
    end

    subgraph Talos["Talos layer"]
        MC[machine config]
    end

    subgraph CloudInit["Cloud-init"]
        ISO[NoCloud ISO]
    end

    subgraph VMs["VM layer"]
        COW[CoW clones of Talos image]
    end

    VMs --> CloudInit
    CloudInit --> Talos
    Talos --> Bootstrap
    Bootstrap --> PostBootstrap
    PostBootstrap --> Outputs
```

| Layer | What | Where |
|-------|-----|-------|
| **VMs** | QEMU/KVM domains, CoW clones of Talos image | KVM host |
| **Cloud-init** | NoCloud ISO with static network config | Attached as CDROM |
| **Talos** | Machine config (hostname, disk, VIP) applied via API | Each node |
| **Bootstrap** | etcd + Kubernetes control plane init | First CP only |
| **Post-bootstrap** | Kubeconfig, NFS CSI (optional) | Terraform outputs + kube-system |

## IP Assignment

VMs get **deterministic** IPs—no DHCP reservations.

```mermaid
flowchart LR
    subgraph Terraform["Terraform"]
        A["Compute IP from<br/>cidr + offset"]
        B["Write to cloud-init<br/>network-config template"]
    end
    subgraph Boot["First boot"]
        C["Talos reads<br/>NoCloud ISO"]
        D["Apply static IP<br/>to eth0"]
        E["Talos API up<br/>at that IP"]
    end
    subgraph Apply["Terraform apply"]
        F["Connect to Talos API<br/>push machine config"]
    end

    A --> B --> C --> D --> E --> F
```

| Step | What |
|------|------|
| **MAC** | `52:54:00:c1:00:01` (CP), `52:54:00:c2:00:01` (workers) |
| **Cloud-init** | NoCloud datasource provides `network-config` with static address |
| **Talos** | Reads cloud-init on first boot, applies IP before API comes up |
| **Terraform** | Connects to Talos API at that IP to push full config |

```
network_cidr: 10.0.0.0/24
cp_ip_offset: 70      → 10.0.0.70, 10.0.0.71, ...
worker_ip_offset: 80  → 10.0.0.80, 10.0.0.81, ...
```

## HA with VIP

When `cluster_vip` is set and you have 3 control plane nodes (see topology diagram above):

- Talos uses **VRRP** to hold a floating Virtual IP
- One CP node owns the VIP; on failure it migrates to a healthy peer
- `cluster_endpoint` points at the VIP so the API is always reachable

> **Best practice:** Use `controlplane_count = 3` with `cluster_vip` for production-like setups.

## File Layout

```
k8s-deploy/
├── main.tf           # Cloud-init ISOs, VMs
├── talos.tf          # Secrets, configs, bootstrap, health, kubeconfig
├── storage.tf       # NFS CSI (optional)
├── image.tf          # Talos image factory (schematic, URL)
├── locals.tf         # Node defs, cloud-init content, libvirt SSH
├── cloud-init/       # Templates: user-data, meta-data, network-config
├── scripts/
│   └── create-cloudinit-iso.sh   # Builds ISO (local or remote)
└── generated/       # kubeconfig, talosconfig (gitignored)
```
