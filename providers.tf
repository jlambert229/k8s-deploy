provider "proxmox" {
  endpoint  = var.proxmox_endpoint
  insecure  = var.proxmox_insecure
  api_token = var.proxmox_api_token

  ssh {
    agent    = true
    username = var.proxmox_ssh_user
  }
}

provider "talos" {}
