provider "libvirt" {
  uri = var.libvirt_uri
}

provider "talos" {}

provider "kubernetes" {
  host                   = local.k8s_client_config.host
  cluster_ca_certificate = base64decode(local.k8s_client_config.ca_certificate)
  client_certificate     = base64decode(local.k8s_client_config.client_certificate)
  client_key             = base64decode(local.k8s_client_config.client_key)
}

provider "helm" {
  kubernetes = {
    host                   = local.k8s_client_config.host
    cluster_ca_certificate = base64decode(local.k8s_client_config.ca_certificate)
    client_certificate     = base64decode(local.k8s_client_config.client_certificate)
    client_key             = base64decode(local.k8s_client_config.client_key)
  }
}
