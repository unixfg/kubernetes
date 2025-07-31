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

# Create namespace for sops-secrets-operator
resource "kubernetes_namespace" "sops_secrets_operator" {
  depends_on = [
    module.aks,
    null_resource.wait_for_cluster,
    null_resource.setup_kubeconfig
  ]
  
  metadata {
    name = "sops-secrets-operator-system"
    labels = {
      "name" = "sops-secrets-operator-system"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
  
  lifecycle {
    create_before_destroy = true
  }
}

# Deploy Azure Key Vault SOPS integration
module "akv_sops" {
  source = "../../modules/akv-sops"
  
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
  
  depends_on = [
    module.aks,
    kubernetes_namespace.sops_secrets_operator,
    null_resource.wait_for_cluster
  ]
}

# Configure Kubernetes provider with cluster connection details
# Uses try() to handle potential race conditions during initial deployment
provider "kubernetes" {
  host                   = length(module.aks.cluster_host) > 0 ? module.aks.cluster_host : null
  client_certificate     = length(module.aks.cluster_client_certificate) > 0 ? base64decode(module.aks.cluster_client_certificate) : null
  client_key             = length(module.aks.cluster_client_key) > 0 ? base64decode(module.aks.cluster_client_key) : null
  cluster_ca_certificate = length(module.aks.cluster_ca_certificate) > 0 ? base64decode(module.aks.cluster_ca_certificate) : null
}

# Configure Helm provider with cluster connection details  
provider "helm" {
  kubernetes {
    host                   = length(module.aks.cluster_host) > 0 ? module.aks.cluster_host : null
    client_certificate     = length(module.aks.cluster_client_certificate) > 0 ? base64decode(module.aks.cluster_client_certificate) : null
    client_key             = length(module.aks.cluster_client_key) > 0 ? base64decode(module.aks.cluster_client_key) : null
    cluster_ca_certificate = length(module.aks.cluster_ca_certificate) > 0 ? base64decode(module.aks.cluster_ca_certificate) : null
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

# Wait for AKS cluster to be fully ready before proceeding
resource "null_resource" "wait_for_cluster" {
  depends_on = [null_resource.setup_kubeconfig]
  
  provisioner "local-exec" {
    command = <<-EOT
      # Wait for cluster to be responsive with retry logic
      echo "Waiting for cluster to be ready..."
      for i in {1..30}; do
        if kubectl cluster-info --request-timeout=10s 2>/dev/null; then
          echo "Cluster is ready! Checking nodes..."
          kubectl get nodes --request-timeout=10s
          echo "Cluster validation complete!"
          exit 0
        fi
        echo "Attempt $i/30: Cluster not ready yet, waiting 10 seconds..."
        sleep 10
      done
      echo "ERROR: Cluster failed to become ready after 300 seconds"
      exit 1
    EOT
    
    interpreter = ["bash", "-c"]
  }
  
  triggers = {
    cluster_name = module.aks.cluster_name
  }
}

# Deploy ArgoCD GitOps Controller using reusable module
# ArgoCD will automatically discover and deploy applications from the GitOps repository
module "argocd" {
  source = "../../modules/argocd"
  
  environment                 = var.environment
  git_repo_url                = var.git_repo_url
  use_ssh_for_git             = var.use_ssh_for_git
  argocd_repo_ssh_secret_name = var.argocd_repo_ssh_secret_name
  create_applicationset       = false  # Disable ApplicationSet creation initially
  
  depends_on = [
    module.aks, 
    module.akv_sops,
    null_resource.setup_kubeconfig,
    null_resource.wait_for_cluster
  ]
}

# Create ApplicationSets separately after ensuring ArgoCD is fully deployed
resource "null_resource" "argocd_ready_check" {
  depends_on = [module.argocd]
  
  provisioner "local-exec" {
    command = <<-EOT
      # Wait for ArgoCD server to be ready
      kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd
      kubectl wait --for=condition=available --timeout=300s deployment/argocd-application-controller -n argocd
      kubectl wait --for=condition=available --timeout=300s deployment/argocd-repo-server -n argocd
    EOT
  }
  
  triggers = {
    argocd_deployment = timestamp()
  }
}
