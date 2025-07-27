# AKS Module - Azure Kubernetes Service cluster provisioning
# This module creates a complete AKS cluster with resource group and random naming

# Generate random pet names for unique and memorable resource naming
resource "random_pet" "cluster" {
  length    = var.random_pet_length
  separator = "-"
}

# Dynamic locals for consistent naming across resources
locals {
  cluster_name  = "aks-${random_pet.cluster.id}"
  rg_name      = "rg-${random_pet.cluster.id}"
  dns_prefix   = random_pet.cluster.id
}

# Create dedicated resource group for the AKS cluster and related resources
resource "azurerm_resource_group" "main" {
  name     = local.rg_name
  location = var.resource_group_location
  
  tags = merge(var.common_tags, {
    component = "aks-cluster"
  })
}

# AKS Cluster with system-assigned managed identity
resource "azurerm_kubernetes_cluster" "main" {
  name                = local.cluster_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  dns_prefix          = local.dns_prefix
  
  # Default node pool configuration
  default_node_pool {
    name                           = "default"
    node_count                    = var.node_count
    vm_size                       = var.vm_size
    temporary_name_for_rotation   = "temp"
  }

  # Use system-assigned managed identity for simplified access management
  identity {
    type = "SystemAssigned"
  }

  # Enable workload identity for Azure integration
  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  tags = merge(var.common_tags, {
    component = "aks-cluster"
  })
}
