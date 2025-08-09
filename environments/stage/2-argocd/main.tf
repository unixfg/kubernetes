###############################################
# Stage Environment - 2-argocd (GitOps/ArgoCD)
###############################################

terraform {
  required_providers {
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

# Consume outputs from 1-azure stack
data "terraform_remote_state" "azure" {
  backend = "local"
  config = {
    path = "../1-azure/terraform.tfstate"
  }
}

# Configure providers with cluster details from 1-azure
provider "kubernetes" {
  host                   = data.terraform_remote_state.azure.outputs.cluster_host
  client_certificate     = base64decode(data.terraform_remote_state.azure.outputs.cluster_client_certificate)
  client_key             = base64decode(data.terraform_remote_state.azure.outputs.cluster_client_key)
  cluster_ca_certificate = base64decode(data.terraform_remote_state.azure.outputs.cluster_ca_certificate)
}

provider "helm" {
  kubernetes {
    host                   = data.terraform_remote_state.azure.outputs.cluster_host
    client_certificate     = base64decode(data.terraform_remote_state.azure.outputs.cluster_client_certificate)
    client_key             = base64decode(data.terraform_remote_state.azure.outputs.cluster_client_key)
    cluster_ca_certificate = base64decode(data.terraform_remote_state.azure.outputs.cluster_ca_certificate)
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
}
