# Naming Module

This Terraform module provides consistent and memorable naming patterns for Azure resources using random pet names.

## Purpose

The naming module generates unique, readable names for Azure resources by:
- Using random pet names (e.g., "blessed-squid", "happy-elephant")
- Ensuring resource name uniqueness across deployments
- Providing memorable names that are easy to identify
- Following Azure naming conventions and length limits

## Features

- **Random Pet Generation**: Creates unique, two-word combinations
- **Configurable Length**: Adjust word count for uniqueness requirements
- **Azure Compliance**: Names meet Azure resource naming requirements
- **Consistent Format**: Standardized naming across all resource types

## Usage

### Basic Example

```hcl
module "naming" {
  source = "../../modules/naming"
  
  environment = "stage"
  length      = 2
}

# Use outputs for resource naming
resource "azurerm_resource_group" "main" {
  name     = "rg-${module.naming.random_suffix}"
  location = var.location
}
```

### With Custom Separator

```hcl
module "naming" {
  source = "../../modules/naming"
  
  environment = "prod"
  length      = 3
  separator   = "-"
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| `environment` | Environment name (dev, stage, prod) | `string` | n/a | yes |
| `length` | Number of words in random pet name | `number` | `2` | no |
| `separator` | Separator character for pet names | `string` | `"-"` | no |

## Outputs

| Name | Description |
|------|-------------|
| `random_suffix` | Generated random pet suffix for resource naming |
| `environment` | Environment name passed through |
| `full_prefix` | Complete prefix including environment |

## Naming Patterns

The module generates names following these patterns:

- **Resource Groups**: `rg-{random-pet}`
- **AKS Clusters**: `aks-{random-pet}`
- **Key Vaults**: `kv-{random-pet}`
- **Storage Accounts**: `st{randompet}` (no hyphens for storage)

## Examples

With `length = 2`:
- `blessed-squid`
- `happy-elephant`
- `clever-dolphin`

With `length = 3`:
- `blessed-jumping-squid`
- `happy-dancing-elephant`
- `clever-swimming-dolphin`

## Best Practices

1. **Consistency**: Use the same naming module across all environments
2. **Length**: Use `length = 2` for most resources, `length = 3` for high-collision scenarios
3. **Documentation**: Include random suffix in resource documentation
4. **State Management**: Pin random values by committing Terraform state

This module ensures your Azure resources have unique, memorable names while maintaining consistency across your infrastructure.