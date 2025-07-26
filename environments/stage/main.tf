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
    null = {
      source  = "hashicorp/null"
      version = "~>3.0"
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

# Configure kubectl and helm providers with the cluster details
# This prevents the chicken-and-egg problem during initial deployment
provider "kubernetes" {
  host                   = try(module.aks.cluster_host, "")
  client_certificate     = try(base64decode(module.aks.cluster_client_certificate), "")
  client_key             = try(base64decode(module.aks.cluster_client_key), "")
  cluster_ca_certificate = try(base64decode(module.aks.cluster_ca_certificate), "")
}

provider "helm" {
  kubernetes {
    host                   = try(module.aks.cluster_host, "")
    client_certificate     = try(base64decode(module.aks.cluster_client_certificate), "")
    client_key             = try(base64decode(module.aks.cluster_client_key), "")
    cluster_ca_certificate = try(base64decode(module.aks.cluster_ca_certificate), "")
  }
}

# Setup kubeconfig after cluster creation
resource "null_resource" "setup_kubeconfig" {
  depends_on = [module.aks]
  
  provisioner "local-exec" {
    command = "az aks get-credentials --resource-group ${module.aks.resource_group_name} --name ${module.aks.cluster_name} --overwrite-existing"
  }
  
  triggers = {
    cluster_name = module.aks.cluster_name
  }
}

# ArgoCD Module - deployed after cluster is ready
module "argocd" {
  source = "../../modules/argocd"
  
  environment                  = var.environment
  git_repo_url                = var.git_repo_url
  use_ssh_for_git             = var.use_ssh_for_git
  argocd_repo_ssh_secret_name = var.argocd_repo_ssh_secret_name
  create_applicationset       = true   # Always enable - we'll handle timing properly
  
  depends_on = [module.aks, null_resource.setup_kubeconfig]
}

# # Rook-Ceph Storage Module - Commented out for now
# module "rook_ceph" {
#   source = "../../modules/rook-ceph"
#   
#   cluster_name          = "${local.environment_name}-ceph"
#   operator_namespace    = "rook-ceph"
#   cluster_namespace     = "rook-ceph"
#   
#   # Ceph configuration for stage environment
#   mon_count            = 3
#   mgr_count            = 2
#   enable_dashboard     = true
#   
#   # Storage configuration
#   enable_block_storage       = true
#   block_storage_default      = true
#   block_pool_replicated_size = 2  # Reduced for stage
#   block_reclaim_policy       = "Delete"
#   
#   # Disable filesystem storage for stage (can enable if needed)
#   enable_filesystem_storage = false
#   
#   # Use all available nodes and devices in stage
#   use_all_nodes   = true
#   use_all_devices = false  # Set to true if you want to use all devices
#   
#   # Resource limits for stage environment
#   operator_resources = {
#     limits = {
#       memory = "256Mi"
#     }
#     requests = {
#       cpu    = "100m"
#       memory = "128Mi"
#     }
#   }
#   
#   cluster_resources = {
#     mon = {
#       limits = {
#         cpu    = "1000m"
#         memory = "1Gi"
#       }
#       requests = {
#         cpu    = "100m"
#         memory = "512Mi"
#       }
#     }
#     mgr = {
#       limits = {
#         cpu    = "500m"
#         memory = "512Mi"
#       }
#       requests = {
#         cpu    = "100m"
#         memory = "256Mi"
#       }
#     }
#     osd = {
#       limits = {
#         cpu    = "1000m"
#         memory = "2Gi"
#       }
#       requests = {
#         cpu    = "100m"
#         memory = "1Gi"
#       }
#     }
#   }
#   
#   depends_on = [module.aks]
# }

# MetalLB Load Balancer Module
module "metallb" {
  source = "../../modules/metallb"
  
  namespace                   = "metallb-system"
  metallb_version            = "v0.15.2"
  metallb_helm_chart_version = "0.15.2"
  enable_bgp                 = false  # Use Layer 2 mode for simplicity in stage
  
  # IP address pools for stage environment
  # For AKS cluster, using a range within the cluster's subnet
  ip_address_pools = [
    {
      name            = "${local.environment_name}-pool"
      addresses       = ["10.240.0.100-10.240.0.150"]  # AKS default subnet range
      auto_assign     = true
      avoid_buggy_ips = false
    }
  ]
  
  # L2 advertisements for Layer 2 mode
  l2_advertisements = [
    {
      name             = "${local.environment_name}-l2"
      ip_address_pools = ["${local.environment_name}-pool"]
      interfaces       = []  # Use all interfaces
    }
  ]
  
  # Resource configuration for stage
  controller_resources = {
    limits = {
      cpu    = "200m"
      memory = "200Mi"
    }
    requests = {
      cpu    = "100m"
      memory = "100Mi"
    }
  }
  
  speaker_resources = {
    limits = {
      cpu    = "200m"
      memory = "200Mi"
    }
    requests = {
      cpu    = "100m"
      memory = "100Mi"
    }
  }
  
  depends_on = [module.aks]
}
