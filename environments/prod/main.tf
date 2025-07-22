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
    name       = "default"
    node_count = var.node_count
    vm_size    = var.vm_size
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

# NOTE: NGINX Ingress, cert-manager, secrets, and DNS management 
# will be managed by ArgoCD applications in the gitops repo
