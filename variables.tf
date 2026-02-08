# --- Proxmox Connection ---

variable "proxmox_endpoint" {
  description = "Proxmox API URL (e.g. https://10.0.0.10:8006)."
  type        = string
}

variable "proxmox_api_token" {
  description = "API token in the format USER@REALM!TOKENID=SECRET."
  type        = string
  sensitive   = true
}

variable "proxmox_insecure" {
  description = "Skip TLS verification (true for self-signed certs)."
  type        = bool
  default     = true
}

variable "proxmox_ssh_user" {
  description = "SSH user for provider operations on the Proxmox host."
  type        = string
  default     = "root"
}

variable "proxmox_node" {
  description = "Target Proxmox node name."
  type        = string
  default     = "pve"
}

# --- Cluster ---

variable "cluster_name" {
  description = "Talos cluster name. Used in machine configs and VM naming."
  type        = string
  default     = "talos"
}

variable "cluster_vip" {
  description = "Virtual IP for the Kubernetes API. Null uses the first control plane IP."
  type        = string
  default     = null
}

# --- Talos ---

variable "talos_version" {
  description = "Talos Linux version (e.g. v1.9.2)."
  type        = string
  default     = "v1.9.2"
}

variable "talos_extensions" {
  description = "Talos system extensions to include in the image (short names)."
  type        = list(string)
  default     = ["qemu-guest-agent"]
}

variable "talos_factory_url" {
  description = "Talos image factory base URL."
  type        = string
  default     = "https://factory.talos.dev"
}

variable "install_disk" {
  description = "Disk device Talos installs to inside the VM."
  type        = string
  default     = "/dev/sda"
}

# --- Network ---

variable "network_cidr" {
  description = "Network CIDR for the cluster (e.g. 192.168.2.0/24). Used with offsets to compute node IPs."
  type        = string
  default     = "10.0.0.0/24"
}

variable "gateway" {
  description = "Default gateway IP."
  type        = string
  default     = "10.0.0.1"
}

variable "nameservers" {
  description = "DNS nameservers for cluster nodes."
  type        = list(string)
  default     = ["1.1.1.1", "8.8.8.8"]
}

variable "network_bridge" {
  description = "Proxmox network bridge."
  type        = string
  default     = "vmbr0"
}

variable "vlan_id" {
  description = "802.1Q VLAN tag. Null for untagged."
  type        = number
  default     = null
}

# --- Control Plane ---

variable "controlplane_count" {
  description = "Number of control plane nodes (1 or 3 recommended)."
  type        = number
  default     = 1
}

variable "controlplane_cpu" {
  description = "vCPU cores per control plane node."
  type        = number
  default     = 2
}

variable "controlplane_memory_mb" {
  description = "RAM in MB per control plane node."
  type        = number
  default     = 4096
}

variable "controlplane_disk_gb" {
  description = "Boot disk size in GB per control plane node."
  type        = number
  default     = 20
}

# --- Workers ---

variable "worker_count" {
  description = "Number of worker nodes."
  type        = number
  default     = 2
}

variable "worker_cpu" {
  description = "vCPU cores per worker node."
  type        = number
  default     = 2
}

variable "worker_memory_mb" {
  description = "RAM in MB per worker node."
  type        = number
  default     = 4096
}

variable "worker_disk_gb" {
  description = "Boot disk size in GB per worker node."
  type        = number
  default     = 50
}

# --- VM IDs & IP Offsets ---

variable "vm_id_base" {
  description = "Starting VM ID. Control planes get base+0..N, workers get base+10..N."
  type        = number
  default     = 400
}

variable "cp_ip_offset" {
  description = "Offset from network base for control plane IPs (e.g. 70 → .70, .71, .72)."
  type        = number
  default     = 70
}

variable "worker_ip_offset" {
  description = "Offset from network base for worker IPs (e.g. 80 → .80, .81)."
  type        = number
  default     = 80
}

# --- Storage ---

variable "image_storage" {
  description = "Proxmox storage for the Talos ISO image download."
  type        = string
  default     = "local"
}

variable "disk_storage" {
  description = "Proxmox storage pool for VM disks."
  type        = string
  default     = "local-lvm"
}
