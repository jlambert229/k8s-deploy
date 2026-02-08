# --- Control Plane VMs ---
# Booted from the Talos nocloud disk image with network-only cloud-init.
# Full Talos configuration is applied via the API in talos.tf.

module "controlplane" {
  source   = "git::https://github.com/jlambert229/terraform-proxmox.git"
  for_each = local.controlplanes

  vm_id     = each.value.vm_id
  name      = each.key
  node_name = var.proxmox_node
  tags      = [var.cluster_name, "controlplane", "talos"]
  on_boot   = true

  # Boot from Talos image
  disk_image_id = proxmox_virtual_environment_download_file.talos.id
  disk_size_gb  = var.controlplane_disk_gb
  disk_storage  = var.disk_storage
  boot_order    = ["scsi0"]

  cpu_cores     = var.controlplane_cpu
  memory_mb     = var.controlplane_memory_mb
  agent_enabled = local.has_guest_agent

  network_bridge = var.network_bridge
  vlan_id        = var.vlan_id

  # Network-only cloud-init (Talos reads this for initial IP)
  initialize                  = true
  initialization_datastore_id = var.disk_storage
  ip_address                  = "${each.value.ip}/${local.network_prefix}"
  gateway                     = var.gateway
  dns                         = var.nameservers
}

# --- Worker VMs ---

module "worker" {
  source   = "git::https://github.com/jlambert229/terraform-proxmox.git"
  for_each = local.workers

  vm_id     = each.value.vm_id
  name      = each.key
  node_name = var.proxmox_node
  tags      = [var.cluster_name, "worker", "talos"]
  on_boot   = true

  # Boot from Talos image
  disk_image_id = proxmox_virtual_environment_download_file.talos.id
  disk_size_gb  = var.worker_disk_gb
  disk_storage  = var.disk_storage
  boot_order    = ["scsi0"]

  cpu_cores     = var.worker_cpu
  memory_mb     = var.worker_memory_mb
  agent_enabled = local.has_guest_agent

  network_bridge = var.network_bridge
  vlan_id        = var.vlan_id

  # Network-only cloud-init
  initialize                  = true
  initialization_datastore_id = var.disk_storage
  ip_address                  = "${each.value.ip}/${local.network_prefix}"
  gateway                     = var.gateway
  dns                         = var.nameservers
}
