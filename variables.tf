# --- Libvirt ---

variable "libvirt_uri" {
  description = "Libvirt connection URI (e.g. qemu:///system or qemu+ssh://user@host/system)."
  type        = string
  default     = "qemu:///system"
}

# --- Cluster ---

variable "cluster_name" {
  description = "Talos cluster name. Used in machine configs and VM naming."
  type        = string
  default     = "talos"
}

variable "cluster_vip" {
  description = "Virtual IP for the Kubernetes API (shared across control plane nodes). Null uses the first control plane IP."
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

variable "talos_image_path" {
  description = "Absolute path to the Talos disk image on the KVM host. Downloaded from the image factory (see README)."
  type        = string

  validation {
    condition     = startswith(var.talos_image_path, "/")
    error_message = "Image path must be an absolute path (starting with /)."
  }
}

variable "talos_image_format" {
  description = "Format of the Talos disk image (raw from factory, or qcow2 if converted)."
  type        = string
  default     = "raw"

  validation {
    condition     = contains(["qcow2", "raw"], var.talos_image_format)
    error_message = "Image format must be 'qcow2' or 'raw'."
  }
}

variable "install_disk" {
  description = "Disk device Talos installs to inside the VM. Use /dev/vda for virtio."
  type        = string
  default     = "/dev/vda"
}

# --- Network ---

variable "network_bridge" {
  description = "Host bridge interface for VM networking."
  type        = string
  default     = "br0"
}

variable "network_cidr" {
  description = "Network CIDR for the cluster (e.g. 10.0.0.0/24). Used with offsets to compute node IPs."
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

# --- Storage ---

variable "storage_pool" {
  description = "Libvirt storage pool for VM volumes."
  type        = string
  default     = "default"
}

# --- Control Plane ---

variable "controlplane_count" {
  description = "Number of control plane nodes (1 or 3 recommended)."
  type        = number
  default     = 1

  validation {
    condition     = var.controlplane_count >= 1
    error_message = "At least one control plane node is required."
  }
}

variable "controlplane_cpu" {
  description = "vCPU cores per control plane node."
  type        = number
  default     = 2
}

variable "controlplane_memory" {
  description = "RAM in MiB per control plane node."
  type        = number
  default     = 4096
}

variable "controlplane_disk" {
  description = "Boot disk size in GiB per control plane node."
  type        = number
  default     = 20
}

# --- Workers ---

variable "worker_count" {
  description = "Number of worker nodes."
  type        = number
  default     = 2

  validation {
    condition     = var.worker_count >= 0
    error_message = "Worker count cannot be negative."
  }
}

variable "worker_cpu" {
  description = "vCPU cores per worker node."
  type        = number
  default     = 2
}

variable "worker_memory" {
  description = "RAM in MiB per worker node."
  type        = number
  default     = 4096
}

variable "worker_disk" {
  description = "Boot disk size in GiB per worker node."
  type        = number
  default     = 50
}

# --- IP Offsets ---

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

# --- Boot ---

variable "uefi" {
  description = "Boot VMs with UEFI firmware (recommended)."
  type        = bool
  default     = true
}
