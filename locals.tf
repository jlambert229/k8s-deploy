locals {
  # Extract prefix length from CIDR (e.g. "192.168.2.0/24" → "24")
  network_prefix = split("/", var.network_cidr)[1]

  # Cluster API endpoint: VIP if set, otherwise first control plane IP
  cluster_endpoint = coalesce(var.cluster_vip, local.first_cp_ip)
  first_cp_ip      = local.controlplanes[keys(local.controlplanes)[0]].ip

  # Whether guest agent extension is included
  has_guest_agent = contains(var.talos_extensions, "qemu-guest-agent")

  # --- Control plane node map ---
  controlplanes = {
    for i in range(var.controlplane_count) : format("%s-cp-%d", var.cluster_name, i + 1) => {
      vm_id = var.vm_id_base + i
      ip    = cidrhost(var.network_cidr, var.cp_ip_offset + i)
    }
  }

  # --- Worker node map ---
  workers = {
    for i in range(var.worker_count) : format("%s-w-%d", var.cluster_name, i + 1) => {
      vm_id = var.vm_id_base + 10 + i
      ip    = cidrhost(var.network_cidr, var.worker_ip_offset + i)
    }
  }
}
