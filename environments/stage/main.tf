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

# Generate random pet names for resources
resource "random_pet" "cluster" {
  length = var.random_pet_length
  separator = "-"
}

# Dynamic environment name from folder
locals {
  environment_name = basename(path.cwd)
  random_suffix    = random_pet.cluster.id
  cluster_name     = "aks-${local.random_suffix}"
  rg_name         = "rg-${local.random_suffix}"
  dns_prefix      = local.random_suffix
}

# Resource Group
resource "azurerm_resource_group" "main" {
  name     = local.rg_name
  location = var.resource_group_location
  
  tags = {
    environment = local.environment_name
    managed     = "terraform"
  }
}

# AKS Cluster
resource "azurerm_kubernetes_cluster" "main" {
  name                = local.cluster_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  dns_prefix          = local.dns_prefix
  
  default_node_pool {
    name                   = "default"
    node_count            = var.node_count
    vm_size               = var.vm_size
    temporary_name_for_rotation = "temp"
  }

  identity {
    type = "SystemAssigned"
  }

  tags = {
    environment = local.environment_name
    managed     = "terraform"
  }
}

# Configure kubectl provider
provider "kubernetes" {
  host                   = azurerm_kubernetes_cluster.main.kube_config.0.host
  client_certificate     = base64decode(azurerm_kubernetes_cluster.main.kube_config.0.client_certificate)
  client_key            = base64decode(azurerm_kubernetes_cluster.main.kube_config.0.client_key)
  cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.main.kube_config.0.cluster_ca_certificate)
}

provider "helm" {
  kubernetes {
    host                   = azurerm_kubernetes_cluster.main.kube_config.0.host
    client_certificate     = base64decode(azurerm_kubernetes_cluster.main.kube_config.0.client_certificate)
    client_key            = base64decode(azurerm_kubernetes_cluster.main.kube_config.0.client_key)
    cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.main.kube_config.0.cluster_ca_certificate)
  }
}

# ArgoCD namespace
resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"
  }
}

# Generate SSH key for ArgoCD repository access
resource "tls_private_key" "argocd_repo" {
  algorithm = "ED25519"
}

# Store private key in Kubernetes Secret
resource "kubernetes_secret" "argocd_repo_ssh" {
  metadata {
    name      = var.argocd_repo_ssh_secret_name
    namespace = kubernetes_namespace.argocd.metadata[0].name
    labels = {
      "argocd.argoproj.io/secret-type" = "repository"
    }
  }

  data = {
    "sshPrivateKey" = tls_private_key.argocd_repo.private_key_openssh
    "url"           = var.use_ssh_for_git ? replace(var.git_repo_url, "https://github.com/", "git@github.com:") : var.git_repo_url
    "type"          = "git"
  }
}

# Install ArgoCD via Helm
resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  namespace  = kubernetes_namespace.argocd.metadata[0].name

  values = [
    yamlencode({
      server = {
        service = {
          type = "ClusterIP"
        }
        extraArgs = ["--insecure"]
      }
    })
  ]
}

# Create ConfigMap with environment configuration for ArgoCD
resource "kubernetes_config_map" "environment_config" {
  depends_on = [azurerm_kubernetes_cluster.main]
  
  metadata {
    name      = "environment-config"
    namespace = "argocd"
  }

  data = {
    environment = var.environment
  }
}

# ArgoCD ApplicationSet for automatic app discovery
resource "kubernetes_manifest" "app_discovery" {
  depends_on = [helm_release.argocd, kubernetes_secret.argocd_repo_ssh]

  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "ApplicationSet"
    metadata = {
      name      = "app-discovery"
      namespace = "argocd"
    }
    spec = {
      generators = [
        {
          git = {
            repoURL        = var.use_ssh_for_git ? replace(var.git_repo_url, "https://github.com/", "git@github.com:") : var.git_repo_url
            revision       = "HEAD"
            directories = [
              {
                path = "apps/*"
              }
            ]
          }
        }
      ]
      template = {
        metadata = {
          name = "{{path.basename}}-${var.environment}"
        }
        spec = {
          project = "default"
          source = {
            repoURL        = var.use_ssh_for_git ? replace(var.git_repo_url, "https://github.com/", "git@github.com:") : var.git_repo_url
            targetRevision = "HEAD"
            path           = "{{path}}/overlays/${var.environment}"
          }
          destination = {
            server    = "https://kubernetes.default.svc"
            namespace = "{{path.basename}}"
          }
          syncPolicy = {
            automated = {
              prune    = true
              selfHeal = true
            }
            syncOptions = [
              "CreateNamespace=true"
            ]
          }
        }
      }
    }
  }
}
