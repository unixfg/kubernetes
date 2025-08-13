###############################################
# Stage Environment - 1-azure (AKS + AKV/SOPS)
###############################################

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

data "azurerm_client_config" "current" {}

# Use parent directory name (e.g., "stage") as environment name
locals {
  environment_name = var.environment != "" ? var.environment : basename(dirname(path.cwd))
  common_tags = {
    environment = local.environment_name
    managed     = "terraform"
  }
}

# AKS Cluster
module "aks" {
  source = "../../../modules/aks"
  resource_group_location = var.resource_group_location
  node_count              = var.node_count
  vm_size                 = var.vm_size
  random_pet_length       = var.random_pet_length
  common_tags             = local.common_tags
}

# Fetch cluster connection data (module encapsulates the actual resource)
data "azurerm_kubernetes_cluster" "cluster" {
  name                = module.aks.cluster_name
  resource_group_name = module.aks.resource_group_name
  depends_on          = [module.aks]
}

# Setup local kubeconfig for kubectl
resource "null_resource" "setup_kubeconfig" {
  depends_on = [module.aks]

  provisioner "local-exec" {
    command = <<-EOT
      set -euo pipefail
      echo "Fetching AKS credentials with retries..."
      for i in $(seq 1 5); do
        if timeout 20 az aks get-credentials --resource-group ${module.aks.resource_group_name} --name ${module.aks.cluster_name} --file $HOME/.kube/config --overwrite-existing; then
          echo "Credentials fetched."
          exit 0
        fi
        echo "Attempt $i/5 failed. Retrying in $((i*2))s..."
        sleep $((i*2))
      done
      echo "Failed to fetch AKS credentials after retries" >&2
      exit 1
    EOT
    interpreter = ["bash", "-c"]
  }

  triggers = {
    cluster_name = module.aks.cluster_name
  }
}

# Wait until cluster responds
resource "null_resource" "wait_for_cluster" {
  depends_on = [null_resource.setup_kubeconfig]

  provisioner "local-exec" {
    command = <<-EOT
      echo "Waiting for cluster to be ready..."
      for i in {1..30}; do
        if timeout 10 kubectl cluster-info --request-timeout=10s 2>/dev/null; then
          echo "Cluster is ready! Checking nodes..."
          timeout 10 kubectl get nodes --request-timeout=10s || true
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

# Azure Key Vault + SOPS integration
module "akv_sops" {
  source = "../../../modules/akv-sops"

  key_vault_name      = "kv${substr(replace(module.aks.random_suffix, "-", ""), 0, 20)}"
  location            = module.aks.resource_group_location
  resource_group_name = module.aks.resource_group_name
  key_name            = "sops-${local.environment_name}"

  soft_delete_retention_days = 7
  purge_protection_enabled   = false

  rbac_assignments = {
    aks_cluster = {
      principal_id         = module.aks.cluster_identity_principal_id
      role_definition_name = "Key Vault Crypto User"
    }
  }

  create_workload_identity      = false
  # workload_identity_name        = "sops-secrets-operator-${local.environment_name}"
  # workload_identity_description = "Kubernetes service account for sops-secrets-operator"
  # oidc_issuer_url               = module.aks.cluster_oidc_issuer_url
  # workload_identity_subject     = "system:serviceaccount:sops-secrets-operator:sops-secrets-operator"

  environment = local.environment_name

  tags = merge(local.common_tags, { component = "sops-encryption" })

  depends_on = [
    module.aks,
    null_resource.wait_for_cluster
  ]
}
