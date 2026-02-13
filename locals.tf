# --- Computed Values ---

locals {
  # Node definitions (order matters for readability; Terraform resolves dependencies)
  controlplanes = {
    for i in range(var.controlplane_count) : format("%s-cp-%d", var.cluster_name, i + 1) => {
      ip   = cidrhost(var.network_cidr, var.cp_ip_offset + i)
      mac  = format("52:54:00:c1:00:%02x", i + 1)
      cpu  = var.controlplane_cpu
      mem  = var.controlplane_memory
      disk = var.controlplane_disk
    }
  }

  workers = {
    for i in range(var.worker_count) : format("%s-w-%d", var.cluster_name, i + 1) => {
      ip   = cidrhost(var.network_cidr, var.worker_ip_offset + i)
      mac  = format("52:54:00:c2:00:%02x", i + 1)
      cpu  = var.worker_cpu
      mem  = var.worker_memory
      disk = var.worker_disk
    }
  }

  all_nodes = merge(local.controlplanes, local.workers)

  # Derived: cluster endpoint, first CP IP
  first_cp_ip      = local.controlplanes[keys(local.controlplanes)[0]].ip
  cluster_endpoint = coalesce(var.cluster_vip, local.first_cp_ip)
  network_prefix   = split("/", var.network_cidr)[1]

  # Libvirt SSH — only set when using qemu+ssh:// (remote). Null for qemu:///system (local).
  libvirt_ssh_user = try(regex("qemu\\+ssh://([^@]+)@", var.libvirt_uri)[0], null)
  libvirt_ssh_host = try(regex("@([^/]+)/", var.libvirt_uri)[0], null)
  libvirt_ssh_dest = local.libvirt_ssh_user != null && local.libvirt_ssh_host != null ? "${local.libvirt_ssh_user}@${local.libvirt_ssh_host}" : null
  libvirt_remote   = local.libvirt_ssh_dest != null

  # Cloud-init: paths and template content (DRY; used in triggers and provisioner env)
  cloudinit_iso_path = { for k in keys(local.all_nodes) : k => "${var.cloudinit_iso_dir}/${k}-cloudinit.iso" }
  cloudinit_user_data = {
    for k, v in local.all_nodes : k => templatefile("${path.module}/cloud-init/user-data.yaml.tpl", {})
  }
  cloudinit_meta_data = {
    for k, v in local.all_nodes : k => templatefile("${path.module}/cloud-init/meta-data.yaml.tpl", { instance_id = k, local_hostname = k })
  }
  cloudinit_network_config = {
    for k, v in local.all_nodes : k => templatefile("${path.module}/cloud-init/network-config.yaml.tpl", {
      mac_address          = v.mac
      ip_address           = v.ip
      network_prefix       = local.network_prefix
      gateway              = var.gateway
      indented_nameservers = join("\n", [for n in var.nameservers : "          - ${n}"])
    })
  }

  # Talos: base patch (hostname + install disk) shared by CP and workers
  talos_base_patches = {
    for k in keys(local.all_nodes) : k => yamlencode({
      machine = {
        network = { hostname = k }
        install = { disk = var.install_disk }
      }
    })
  }

  k8s_client_config = talos_cluster_kubeconfig.this.kubernetes_client_configuration
}
