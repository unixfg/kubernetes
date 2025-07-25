# AKS Module

This module provisions an Azure Kubernetes Service (AKS) cluster with best practices and consistent naming.

## Features

- **Random Naming**: Uses random pet names for consistent and unique resource naming
- **Resource Group**: Creates a dedicated resource group for the cluster
- **AKS Cluster**: Provisions an AKS cluster with system-assigned managed identity
- **Configurable**: Supports customizable node count, VM size, and location
- **Tagging**: Applies common tags to all resources for better organization

## Usage

```hcl
module "aks" {
  source = "../../modules/aks"
  
  resource_group_location = "northcentralus"
  node_count             = 3
  vm_size                = "Standard_B2ms"
  random_pet_length      = 2
  common_tags = {
    environment = "dev"
    managed     = "terraform"
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| resource_group_location | Azure region for resources | `string` | `"northcentralus"` | no |
| node_count | Number of AKS nodes | `number` | `3` | no |
| vm_size | VM size for AKS nodes | `string` | `"Standard_B2ms"` | no |
| random_pet_length | Length of random pet name for resource naming | `number` | `2` | no |
| common_tags | Common tags to apply to all resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| cluster_name | Generated AKS cluster name |
| resource_group_name | Generated resource group name |
| resource_group_location | Resource group location |
| random_suffix | Random pet suffix used for naming |
| cluster_host | Kubernetes cluster endpoint (sensitive) |
| cluster_client_certificate | Kubernetes cluster client certificate (sensitive) |
| cluster_client_key | Kubernetes cluster client key (sensitive) |
| cluster_ca_certificate | Kubernetes cluster CA certificate (sensitive) |
| kube_config_raw | Raw kubeconfig for the cluster (sensitive) |
| cluster_credentials_command | Command to configure kubectl for this cluster |

## Requirements

- Terraform >= 1.0
- azurerm provider ~> 3.0
- random provider ~> 3.0
