# Basic AKS cluster with ArgoCD
# This is the minimal viable infrastructure

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~>2.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~>2.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~>3.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~>4.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# Get current user info
data "azurerm_client_config" "current" {}

# Dynamic environment name from folder
locals {
  environment_name = basename(path.cwd)
  common_tags = {
    environment = local.environment_name
    managed     = "terraform"
  }
}

# AKS Cluster Module
module "aks" {
  source = "../../modules/aks"
  
  resource_group_location = var.resource_group_location
  node_count             = var.node_count
  vm_size                = var.vm_size
  random_pet_length      = var.random_pet_length
  common_tags            = local.common_tags
}

# Configure kubectl provider
provider "kubernetes" {
  host                   = module.aks.cluster_host
  client_certificate     = base64decode(module.aks.cluster_client_certificate)
  client_key            = base64decode(module.aks.cluster_client_key)
  cluster_ca_certificate = base64decode(module.aks.cluster_ca_certificate)
}

provider "helm" {
  kubernetes {
    host                   = module.aks.cluster_host
    client_certificate     = base64decode(module.aks.cluster_client_certificate)
    client_key            = base64decode(module.aks.cluster_client_key)
    cluster_ca_certificate = base64decode(module.aks.cluster_ca_certificate)
  }
}

# ArgoCD Module
module "argocd" {
  source = "../../modules/argocd"
  
  environment                  = var.environment
  git_repo_url                = var.git_repo_url
  use_ssh_for_git             = var.use_ssh_for_git
  argocd_repo_ssh_secret_name = var.argocd_repo_ssh_secret_name
  
  depends_on = [module.aks]
}
