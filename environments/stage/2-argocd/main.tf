###############################################
# Stage Environment - 2-argocd (GitOps/ArgoCD)
###############################################

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
  }
}

# Use parent directory name (e.g., "stage") as environment name
locals {
  environment_name = basename(dirname(path.cwd))
}

# Azure provider configuration
provider "azurerm" {
  features {}
}

# Consume outputs from 1-azure stack
data "terraform_remote_state" "azure" {
  backend = "local"
  config = {
    path = "../1-azure/terraform.tfstate"
  }
}

# Fetch cluster connection data using outputs from Stage 1
data "azurerm_kubernetes_cluster" "cluster" {
  name                = data.terraform_remote_state.azure.outputs.cluster_name
  resource_group_name = data.terraform_remote_state.azure.outputs.resource_group_name
}

# Configure providers with cluster details directly (no kubeconfig context dependency)
provider "kubernetes" {
  host                   = data.azurerm_kubernetes_cluster.cluster.kube_config[0].host
  client_certificate     = base64decode(data.azurerm_kubernetes_cluster.cluster.kube_config[0].client_certificate)
  client_key             = base64decode(data.azurerm_kubernetes_cluster.cluster.kube_config[0].client_key)
  cluster_ca_certificate = base64decode(data.azurerm_kubernetes_cluster.cluster.kube_config[0].cluster_ca_certificate)
}

provider "helm" {
  kubernetes {
    host                   = data.azurerm_kubernetes_cluster.cluster.kube_config[0].host
    client_certificate     = base64decode(data.azurerm_kubernetes_cluster.cluster.kube_config[0].client_certificate)
    client_key             = base64decode(data.azurerm_kubernetes_cluster.cluster.kube_config[0].client_key)
    cluster_ca_certificate = base64decode(data.azurerm_kubernetes_cluster.cluster.kube_config[0].cluster_ca_certificate)
  }
}

# Namespace for sops-secrets-operator (moved from Stage 1)
resource "kubernetes_namespace" "sops_secrets_operator" {
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

# ArgoCD GitOps Controller
module "argocd" {
  source = "../../../modules/argocd"

  environment                 = var.environment
  git_repo_url                = var.git_repo_url
  use_ssh_for_git             = var.use_ssh_for_git
  argocd_repo_ssh_secret_name = var.argocd_repo_ssh_secret_name
  create_applicationset       = var.enable_applicationsets
  
  argocd_values = {
    server = {
      service = {
        type = "ClusterIP"
      }
      extraArgs = ["--insecure"]
      resources = {
        limits = {
          memory = "256Mi"
          cpu    = "500m"
        }
        requests = {
          memory = "128Mi"
          cpu    = "100m"
        }
      }
    }
    controller = {
      resources = {
        limits = {
          memory = "512Mi"
          cpu    = "1000m"
        }
        requests = {
          memory = "256Mi"
          cpu    = "200m"
        }
      }
    }
    repoServer = {
      resources = {
        limits = {
          memory = "256Mi"
          cpu    = "500m"
        }
        requests = {
          memory = "128Mi"
          cpu    = "100m"
        }
      }
    }
    applicationSet = {
      resources = {
        limits = {
          memory = "128Mi"
          cpu    = "200m"
        }
        requests = {
          memory = "64Mi"
          cpu    = "50m"
        }
      }
    }
  }
}
