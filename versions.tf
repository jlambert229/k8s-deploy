terraform {
  required_version = ">= 1.5.0"

  # State: defaults to local. For remote state, add:
  #   backend "s3" { bucket = "..."; key = "k8s-deploy/terraform.tfstate"; region = "..." }
  #   backend "gcs" { bucket = "..."; prefix = "k8s-deploy" }
  #   backend "azurerm" { resource_group_name = "..."; storage_account_name = "..."; ... }

  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "~> 0.9"
    }
    talos = {
      source  = "siderolabs/talos"
      version = "~> 0.7"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.25"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
  }
}
