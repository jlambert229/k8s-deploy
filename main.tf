# --- Control Plane VMs ---
# Booted from the Talos nocloud disk image with cloud-init for initial networking.
# Full Talos configuration is applied via the API in talos.tf.

module "controlplane" {
  source   = "../terraform-libvirt/modules/vm"
  for_each = local.controlplanes

  name     = each.key
  template = var.talos_image_path

  cpu             = var.controlplane_cpu
  memory          = var.controlplane_memory
  disk            = var.controlplane_disk
  template_format = var.talos_image_format
  pool            = var.storage_pool

  network_bridge = var.network_bridge
  mac_address    = each.value.mac

  uefi      = var.uefi
  autostart = true
  running   = true

  # Cloud-init network config — gives the node its static IP on first boot
  # so the Talos API is reachable for machine config application.
  cloudinit_network_config = yamlencode({
    version = 1
    config = [{
      type        = "physical"
      name        = "eth0"
      mac_address = each.value.mac
      subnets = [{
        type            = "static"
        address         = "${each.value.ip}/${local.network_prefix}"
        gateway         = var.gateway
        dns_nameservers = var.nameservers
      }]
    }]
  })
}

# --- Worker VMs ---

module "worker" {
  source   = "../terraform-libvirt/modules/vm"
  for_each = local.workers

  name     = each.key
  template = var.talos_image_path

  cpu             = var.worker_cpu
  memory          = var.worker_memory
  disk            = var.worker_disk
  template_format = var.talos_image_format
  pool            = var.storage_pool

  network_bridge = var.network_bridge
  mac_address    = each.value.mac

  uefi      = var.uefi
  autostart = true
  running   = true

  cloudinit_network_config = yamlencode({
    version = 1
    config = [{
      type        = "physical"
      name        = "eth0"
      mac_address = each.value.mac
      subnets = [{
        type            = "static"
        address         = "${each.value.ip}/${local.network_prefix}"
        gateway         = var.gateway
        dns_nameservers = var.nameservers
      }]
    }]
  })
}
