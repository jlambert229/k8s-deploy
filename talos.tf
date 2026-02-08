# --- Machine Secrets ---
# Generated once per cluster. Contains all certs and tokens needed for
# Talos and Kubernetes communication.

resource "talos_machine_secrets" "this" {
  talos_version = var.talos_version
}

# --- Machine Configurations ---
# Base configs for control plane and worker node types.
# Per-node customization (hostname, install disk) is done via config_patches
# in the talos_machine_configuration_apply resources below.

data "talos_machine_configuration" "controlplane" {
  cluster_name     = var.cluster_name
  cluster_endpoint = "https://${local.cluster_endpoint}:6443"
  machine_type     = "controlplane"
  machine_secrets  = talos_machine_secrets.this.machine_secrets
  talos_version    = var.talos_version
}

data "talos_machine_configuration" "worker" {
  cluster_name     = var.cluster_name
  cluster_endpoint = "https://${local.cluster_endpoint}:6443"
  machine_type     = "worker"
  machine_secrets  = talos_machine_secrets.this.machine_secrets
  talos_version    = var.talos_version
}

# --- Client Configuration ---
# Generates talosconfig for talosctl CLI access.

data "talos_client_configuration" "this" {
  cluster_name         = var.cluster_name
  client_configuration = talos_machine_secrets.this.client_configuration
  endpoints            = [for _, cp in local.controlplanes : cp.ip]
}

# --- Apply Configs to Control Plane Nodes ---
# Pushes the full Talos machine config to each CP node via the Talos API.
# The node must be reachable (has IP from cloud-init) before this runs.

resource "talos_machine_configuration_apply" "controlplane" {
  depends_on = [module.controlplane]
  for_each   = local.controlplanes

  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.controlplane.machine_configuration
  node                        = each.value.ip
  config_patches = [
    yamlencode({
      machine = {
        network = {
          hostname = each.key
        }
        install = {
          disk = var.install_disk
        }
      }
    })
  ]
}

# --- Apply Configs to Worker Nodes ---

resource "talos_machine_configuration_apply" "worker" {
  depends_on = [module.worker]
  for_each   = local.workers

  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.worker.machine_configuration
  node                        = each.value.ip
  config_patches = [
    yamlencode({
      machine = {
        network = {
          hostname = each.key
        }
        install = {
          disk = var.install_disk
        }
      }
    })
  ]
}

# --- Bootstrap ---
# Initializes etcd and the Kubernetes control plane on the first CP node.
# This only needs to happen once — additional CP nodes join automatically.

resource "talos_machine_bootstrap" "this" {
  depends_on = [talos_machine_configuration_apply.controlplane]

  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = local.first_cp_ip
  endpoint             = local.first_cp_ip
}

# --- Kubeconfig ---
# Retrieves the admin kubeconfig after the cluster is bootstrapped.

resource "talos_cluster_kubeconfig" "this" {
  depends_on = [talos_machine_bootstrap.this]

  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = local.first_cp_ip
  endpoint             = local.first_cp_ip
}

# --- Write configs to disk ---
# Written after health check confirms the cluster is ready.

resource "local_sensitive_file" "kubeconfig" {
  depends_on = [data.talos_cluster_health.this]

  content         = talos_cluster_kubeconfig.this.kubeconfig_raw
  filename        = "${path.module}/generated/kubeconfig"
  file_permission = "0600"
}

resource "local_sensitive_file" "talosconfig" {
  depends_on = [data.talos_cluster_health.this]

  content         = data.talos_client_configuration.this.talos_config
  filename        = "${path.module}/generated/talosconfig"
  file_permission = "0600"
}

# --- Health Check ---
# Waits for all nodes to be healthy before marking the deployment complete.

data "talos_cluster_health" "this" {
  depends_on = [
    talos_machine_bootstrap.this,
    talos_machine_configuration_apply.controlplane,
    talos_machine_configuration_apply.worker,
  ]

  client_configuration = data.talos_client_configuration.this.client_configuration
  control_plane_nodes  = [for _, cp in local.controlplanes : cp.ip]
  worker_nodes         = [for _, w in local.workers : w.ip]
  endpoints            = data.talos_client_configuration.this.endpoints

  timeouts = {
    read = "10m"
  }
}
