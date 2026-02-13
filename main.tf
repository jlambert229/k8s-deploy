# --- Cloud-Init ISOs ---
# Local (qemu:///system): script creates ISO on the same host. Remote (qemu+ssh://): streams via SSH.
# Talos reads network-config on first boot for initial IP assignment.

locals {
  cloudinit_iso_path = { for k in keys(local.all_nodes) : k => "${var.cloudinit_iso_dir}/${k}-cloudinit.iso" }
}

resource "terraform_data" "cloudinit" {
  for_each = local.all_nodes

  input = {
    name     = each.key
    ssh_dest = local.libvirt_ssh_dest
    iso_path = local.cloudinit_iso_path[each.key]
    remote   = local.libvirt_remote
  }

  triggers_replace = [
    local.cloudinit_user_data[each.key],
    local.cloudinit_meta_data[each.key],
    local.cloudinit_network_config[each.key],
  ]

  provisioner "local-exec" {
    command = "bash ${path.module}/scripts/create-cloudinit-iso.sh"
    environment = {
      LIBVIRT_SSH_DEST   = local.libvirt_ssh_dest != null ? local.libvirt_ssh_dest : ""
      CLOUDINIT_ISO_PATH = local.cloudinit_iso_path[each.key]
      USER_DATA_B64      = base64encode(local.cloudinit_user_data[each.key])
      META_DATA_B64      = base64encode(local.cloudinit_meta_data[each.key])
      NETWORK_CONFIG_B64 = base64encode(local.cloudinit_network_config[each.key])
    }
  }

  provisioner "local-exec" {
    when    = destroy
    command = self.output.remote ? "ssh ${self.output.ssh_dest} 'sudo rm -f ${self.output.iso_path}' 2>/dev/null || true" : "rm -f ${self.output.iso_path} 2>/dev/null || true"
  }
}

# --- VMs ---
# Booted from Talos nocloud image with cloud-init for initial networking.
# Full Talos config applied via API in talos.tf. Pre-built ISO required for remote libvirt.

module "node" {
  source     = "../terraform-libvirt/modules/vm"
  for_each   = local.all_nodes
  depends_on = [terraform_data.cloudinit]

  name     = each.key
  template = var.talos_image_path

  cpu             = each.value.cpu
  memory          = each.value.mem
  disk            = each.value.disk
  template_format = var.talos_image_format
  pool            = var.storage_pool

  network_bridge      = var.network_bridge
  mac_address         = each.value.mac
  uefi                = var.uefi
  autostart           = true
  running             = true
  cloudinit_disk_path = local.cloudinit_iso_path[each.key]
}
