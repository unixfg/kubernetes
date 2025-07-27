# Terraform Modules

This directory contains reusable Terraform modules for provisioning and managing Kubernetes infrastructure

## Architecture

The infrastructure is organized using a modular approach to promote DRY (Don't Repeat Yourself) principles and maintainability:

```
modules/
├── aks/       # Azure Kubernetes Service cluster provisioning
├── akv-sops/  # Azure Key Vault SOPS integration for secret encryption
└── argocd/    # ArgoCD GitOps deployment and management
```

## Modules Overview

| Module      | Purpose                                                      |
|-------------|--------------------------------------------------------------|
| `aks`       | Provisions Azure Kubernetes Service clusters, resource groups, random naming, and cluster configuration. Provides cluster credentials and connection details. Supports customizable node count, VM sizes, and tagging. |
| `akv-sops`  | Creates and configures Azure Key Vault for SOPS secret encryption, including RBAC, SOPS key, and workload identity for sops-secrets-operator. Outputs configuration for GitOps consumption. |
| `argocd`    | Installs ArgoCD via Helm for GitOps workflows, manages SSH keys for private repository access, creates ApplicationSets for automatic app discovery, and supports configurable sync policies and application directories. |

## GitOps Application Management

Applications such as MetalLB and other infrastructure components are managed through ArgoCD and GitOps commits. This approach provides:
- Declarative configuration stored in Git
- Automatic synchronization of desired state
- Version-controlled application deployments
- Easy rollbacks and audit trails

## Usage Pattern

Each environment (`dev`, `stage`, `prod`) uses these modules in a consistent pattern:

```hcl
# AKS Cluster Module
module "aks" {
  source = "../../modules/aks"
  resource_group_location = var.resource_group_location
  node_count             = var.node_count
  vm_size                = var.vm_size
  random_pet_length      = var.random_pet_length
  common_tags            = local.common_tags
}

# Azure Key Vault SOPS Module
module "akv_sops" {
  source = "../../modules/akv-sops"
  key_vault_name      = "kv-sops-${module.aks.random_suffix}"
  location            = module.aks.resource_group_location
  resource_group_name = module.aks.resource_group_name
  environment         = var.environment
  # ...other configuration...
  depends_on = [module.aks]
}

# ArgoCD Module
module "argocd" {
  source = "../../modules/argocd"
  environment                  = var.environment
  git_repo_url                 = var.git_repo_url
  use_ssh_for_git              = var.use_ssh_for_git
  argocd_repo_ssh_secret_name  = var.argocd_repo_ssh_secret_name
  depends_on = [module.aks]
}
```

## Benefits of Modularization

1. **DRY Principle**: Eliminates code duplication across environments
2. **Consistency**: Ensures all environments follow the same patterns
3. **Maintainability**: Changes in one place apply everywhere
4. **Testability**: Modules can be tested independently
5. **Reusability**: Modules can be used in other projects
6. **Version Control**: Each module can be versioned independently

## Environment Customization

While the modules provide consistency, each environment can customize:
- Node counts and VM sizes
- ArgoCD and SOPS configuration values
- Git repository settings
- Tagging strategies
- Sync policies

## Dependencies
- **AKS** provides the foundational Kubernetes cluster
- **akv-sops** provisions Key Vault and SOPS integration for secret management
- **ArgoCD** deploys to AKS and manages the application lifecycle
