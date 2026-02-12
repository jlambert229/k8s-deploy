# --- Computed Values ---

locals {
  # Extract prefix length from CIDR (e.g. "10.0.0.0/24" → "24")
  network_prefix = split("/", var.network_cidr)[1]

  # Cluster API endpoint: VIP if set, otherwise first control plane IP
  cluster_endpoint = coalesce(var.cluster_vip, local.first_cp_ip)
  first_cp_ip      = local.controlplanes[keys(local.controlplanes)[0]].ip

  # --- Control plane node map ---
  # Each node gets a deterministic name, IP, and MAC address.
  # MACs use the QEMU OUI (52:54:00) with c1 identifying control plane nodes.
  # The MAC is used in cloud-init network config for interface matching.
  controlplanes = {
    for i in range(var.controlplane_count) : format("%s-cp-%d", var.cluster_name, i + 1) => {
      ip  = cidrhost(var.network_cidr, var.cp_ip_offset + i)
      mac = format("52:54:00:c1:00:%02x", i + 1)
    }
  }

  # --- Worker node map ---
  # Same pattern, c2 identifies worker nodes.
  workers = {
    for i in range(var.worker_count) : format("%s-w-%d", var.cluster_name, i + 1) => {
      ip  = cidrhost(var.network_cidr, var.worker_ip_offset + i)
      mac = format("52:54:00:c2:00:%02x", i + 1)
    }
  }
}
