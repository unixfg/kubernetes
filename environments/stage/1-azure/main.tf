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

# Configure providers to talk to the cluster created above
provider "kubernetes" {
  host                   = length(module.aks.cluster_host) > 0 ? module.aks.cluster_host : null
  client_certificate     = length(module.aks.cluster_client_certificate) > 0 ? base64decode(module.aks.cluster_client_certificate) : null
  client_key             = length(module.aks.cluster_client_key) > 0 ? base64decode(module.aks.cluster_client_key) : null
  cluster_ca_certificate = length(module.aks.cluster_ca_certificate) > 0 ? base64decode(module.aks.cluster_ca_certificate) : null
}

provider "helm" {
  kubernetes {
    host                   = length(module.aks.cluster_host) > 0 ? module.aks.cluster_host : null
    client_certificate     = length(module.aks.cluster_client_certificate) > 0 ? base64decode(module.aks.cluster_client_certificate) : null
    client_key             = length(module.aks.cluster_client_key) > 0 ? base64decode(module.aks.cluster_client_key) : null
    cluster_ca_certificate = length(module.aks.cluster_ca_certificate) > 0 ? base64decode(module.aks.cluster_ca_certificate) : null
  }
}

# Setup local kubeconfig for kubectl
resource "null_resource" "setup_kubeconfig" {
  depends_on = [module.aks]

  provisioner "local-exec" {
    command = "az aks get-credentials --resource-group ${module.aks.resource_group_name} --name ${module.aks.cluster_name} --file $HOME/.kube/config --overwrite-existing"
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
        if kubectl cluster-info --request-timeout=10s 2>/dev/null; then
          echo "Cluster is ready! Checking nodes..."
          kubectl get nodes --request-timeout=10s || true
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

# Namespace for sops-secrets-operator
resource "kubernetes_namespace" "sops_secrets_operator" {
  depends_on = [
    module.aks,
    null_resource.wait_for_cluster,
    null_resource.setup_kubeconfig
  ]

  metadata {
    name = "sops-secrets-operator"
    labels = {
      "name"                         = "sops-secrets-operator"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  lifecycle {
    create_before_destroy = true
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

  create_workload_identity      = true
  workload_identity_name        = "sops-secrets-operator-${local.environment_name}"
  workload_identity_description = "Kubernetes service account for sops-secrets-operator"
  oidc_issuer_url               = module.aks.cluster_oidc_issuer_url
  workload_identity_subject     = "system:serviceaccount:sops-secrets-operator:sops-secrets-operator"

  environment = local.environment_name

  tags = merge(local.common_tags, { component = "sops-encryption" })

  depends_on = [
    module.aks,
    kubernetes_namespace.sops_secrets_operator,
    null_resource.wait_for_cluster
  ]
}
