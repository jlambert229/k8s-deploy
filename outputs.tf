# --- Talos Config ---

output "talosconfig" {
  description = "Talos client configuration for talosctl."
  value       = data.talos_client_configuration.this.talos_config
  sensitive   = true
}

# --- Kubeconfig ---

output "kubeconfig" {
  description = "Kubernetes admin kubeconfig."
  value       = talos_cluster_kubeconfig.this.kubeconfig_raw
  sensitive   = true
}

output "kubernetes_client_configuration" {
  description = "Kubernetes client configuration components."
  value = {
    host               = talos_cluster_kubeconfig.this.kubernetes_client_configuration.host
    ca_certificate     = talos_cluster_kubeconfig.this.kubernetes_client_configuration.ca_certificate
    client_certificate = talos_cluster_kubeconfig.this.kubernetes_client_configuration.client_certificate
    client_key         = talos_cluster_kubeconfig.this.kubernetes_client_configuration.client_key
  }
  sensitive = true
}

# --- Node IPs ---

output "controlplane_ips" {
  description = "Control plane node IP addresses."
  value       = { for name, cp in local.controlplanes : name => cp.ip }
}

output "worker_ips" {
  description = "Worker node IP addresses."
  value       = { for name, w in local.workers : name => w.ip }
}

output "cluster_endpoint" {
  description = "Kubernetes API endpoint."
  value       = "https://${local.cluster_endpoint}:6443"
}

# --- Image ---

output "talos_schematic_id" {
  description = "Talos image factory schematic ID (needed for upgrades)."
  value       = talos_image_factory_schematic.this.id
}
