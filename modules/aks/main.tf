# AKS Module - Azure Kubernetes Service cluster provisioning

# Generate random pet names for resources
resource "random_pet" "cluster" {
  length    = var.random_pet_length
  separator = "-"
}

# Dynamic locals for naming consistency
locals {
  cluster_name  = "aks-${random_pet.cluster.id}"
  rg_name      = "rg-${random_pet.cluster.id}"
  dns_prefix   = random_pet.cluster.id
}

# Resource Group
resource "azurerm_resource_group" "main" {
  name     = local.rg_name
  location = var.resource_group_location
  
  tags = merge(var.common_tags, {
    component = "aks-cluster"
  })
}

# AKS Cluster
resource "azurerm_kubernetes_cluster" "main" {
  name                = local.cluster_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  dns_prefix          = local.dns_prefix
  
  default_node_pool {
    name                           = "default"
    node_count                    = var.node_count
    vm_size                       = var.vm_size
    temporary_name_for_rotation   = "temp"
  }

  identity {
    type = "SystemAssigned"
  }

  tags = merge(var.common_tags, {
    component = "aks-cluster"
  })
}
