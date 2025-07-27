# Kubernetes Environment Infrastructure - Stage
# Deploys AKS cluster with ArgoCD for GitOps-based application deployment
# This configuration creates the foundation for a complete Kubernetes environment

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~>2.0"
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

# Configure Azure Resource Manager provider
provider "azurerm" {
  features {}
}

# Get current Azure user/service principal configuration
data "azurerm_client_config" "current" {}

# Dynamic configuration based on environment folder name
locals {
  environment_name = basename(path.cwd)
  common_tags = {
    environment = local.environment_name
    managed     = "terraform"
  }
}

# Deploy AKS Cluster using reusable module
module "aks" {
  source = "../../modules/aks"
  
  resource_group_location = var.resource_group_location
  node_count             = var.node_count
  vm_size                = var.vm_size
  random_pet_length      = var.random_pet_length
  common_tags            = local.common_tags
}

# Deploy SOPS Operator for secret encryption
module "sops_operator" {
  source = "../../modules/sops-operator"
  
  # Azure Key Vault configuration
  key_vault_name      = "kv-sops-${module.aks.random_suffix}"
  location            = module.aks.resource_group_location
  resource_group_name = module.aks.resource_group_name
  key_name            = "sops-${local.environment_name}"
  
  soft_delete_retention_days = 7
  purge_protection_enabled   = false  # Set to true for production
  
  # Grant AKS cluster access via RBAC
  rbac_assignments = {
    aks_cluster = {
      principal_id         = module.aks.cluster_identity_principal_id
      role_definition_name = "Key Vault Crypto User"
    }
  }
  
  # Workload identity configuration
  create_workload_identity      = true
  workload_identity_name        = "sops-secrets-operator-${local.environment_name}"
  workload_identity_description = "Kubernetes service account for sops-secrets-operator"
  oidc_issuer_url              = module.aks.cluster_oidc_issuer_url
  workload_identity_subject    = "system:serviceaccount:sops-secrets-operator-system:sops-secrets-operator"
  
  environment = local.environment_name
  
  tags = merge(local.common_tags, {
    component = "sops-encryption"
  })
}

# Configure Kubernetes provider with cluster connection details
# Uses try() to handle potential race conditions during initial deployment
provider "kubernetes" {
  host                   = try(module.aks.cluster_host, "")
  client_certificate     = try(base64decode(module.aks.cluster_client_certificate), "")
  client_key             = try(base64decode(module.aks.cluster_client_key), "")
  cluster_ca_certificate = try(base64decode(module.aks.cluster_ca_certificate), "")
}

# Configure Helm provider with cluster connection details  
provider "helm" {
  kubernetes {
    host                   = try(module.aks.cluster_host, "")
    client_certificate     = try(base64decode(module.aks.cluster_client_certificate), "")
    client_key             = try(base64decode(module.aks.cluster_client_key), "")
    cluster_ca_certificate = try(base64decode(module.aks.cluster_ca_certificate), "")
  }
}

# Configure local kubeconfig for kubectl access
# This ensures kubectl commands work immediately after deployment
resource "null_resource" "setup_kubeconfig" {
  depends_on = [module.aks]
  
  provisioner "local-exec" {
    command = "az aks get-credentials --resource-group ${module.aks.resource_group_name} --name ${module.aks.cluster_name} --overwrite-existing"
  }
  
  triggers = {
    cluster_name = module.aks.cluster_name
  }
}

# Deploy ArgoCD GitOps Controller using reusable module
# ArgoCD will automatically discover and deploy applications from the GitOps repository
module "argocd" {
  source = "../../modules/argocd"
  
  environment                  = var.environment
  git_repo_url                = var.git_repo_url
  use_ssh_for_git             = var.use_ssh_for_git
  argocd_repo_ssh_secret_name = var.argocd_repo_ssh_secret_name
  create_applicationset       = true
  
  depends_on = [
    module.aks, 
    module.sops_operator,
    null_resource.setup_kubeconfig
  ]
}

# Future Infrastructure Components (commented out for GitOps deployment)
# Note: All applications (MetalLB, Rook-Ceph, etc.) are now deployed via GitOps/ArgoCD
# This provides better separation of concerns and declarative management
# See the GitOps repository for application configurations
# Example: Rook-Ceph storage cluster (disabled - deploy via GitOps instead)
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

# Example: MetalLB load balancer (disabled - deploy via GitOps instead)
# MetalLB configuration can be found in the GitOps repository
# This allows for declarative management and easy updates without Terraform
