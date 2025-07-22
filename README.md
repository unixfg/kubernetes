# Kubernetes Infrastructure

This repository contains Terraform infrastructure code for deploying Azure Kubernetes Service (AKS) clusters with ArgoCD for GitOps-based application management.

## Overview

This infrastructure repository focuses solely on platform provisioning and provides:

- **AKS Clusters** with random pet naming for unique identification
- **ArgoCD** deployed with HTTP access for GitOps management
- **Multi-environment support** (dev, stage, prod) with environment-specific configurations
- **Clean separation** between infrastructure and application concerns

## Repository Structure

```
kubernetes/
├── environments/
│   ├── dev/           # Development environment
│   ├── stage/         # Staging environment
│   └── prod/          # Production environment
```

Each environment contains:
- `main.tf` - Infrastructure definitions
- `variables.tf` - Variable declarations
- `outputs.tf` - Output values
- `terraform.tfvars` - Environment-specific configuration

## Features

- **Random Pet Naming**: Resources are named using memorable random combinations (e.g., `aks-gorgeous-macaw`)
- **Environment Isolation**: Each environment has its own resource group and configuration
- **GitOps Ready**: ArgoCD is pre-configured to manage applications from a separate repository
- **Minimal Dependencies**: Only deploys essential platform components
- **No Secrets**: All sensitive configuration is managed through GitOps applications

## Quick Start

### Prerequisites

- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli) installed and authenticated
- [Terraform](https://www.terraform.io/downloads.html) >= 1.0
- [kubectl](https://kubernetes.io/docs/tasks/tools/) for cluster access

### 1. Clone and Navigate

```bash
git clone <this-repository>
cd kubernetes/environments/dev  # or stage/prod
```

### 2. Initialize Terraform

```bash
terraform init
```

### 3. Review Configuration

Check `terraform.tfvars` for environment-specific settings:
```hcl
environment = "dev"
node_count = 2
vm_size = "Standard_B2s"
resource_group_location = "northcentralus"
```

### 4. Deploy Infrastructure

```bash
terraform plan
terraform apply
```

### 5. Connect to Cluster

```bash
# Get cluster credentials (output from terraform)
az aks get-credentials --resource-group rg-<random-pet> --name aks-<random-pet>

# Access ArgoCD via port forwarding
kubectl port-forward svc/argocd-server -n argocd 8080:80
```

### 6. Access ArgoCD

- **URL**: http://localhost:8080
- **Username**: `admin`
- **Password**: Get with `kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d`

## Environment Specifications

| Environment | Nodes | VM Size | Use Case |
|-------------|-------|---------|----------|
| dev | 2 | Standard_B2s | Development and testing |
| stage | 3 | Standard_B2ms | Pre-production validation |
| prod | 5 | Standard_D2s_v3 | Production workloads |

## GitOps Integration

This infrastructure repository is designed to work with a separate GitOps repository for application management:

- **Infrastructure Repo** (this): Manages AKS clusters and ArgoCD
- **GitOps Repo**: Manages applications, ingress, certificates, and DNS

ArgoCD is configured to sync applications from:
- Repository: `https://github.com/unixfg/kubernetes-config.git`
- Branch: Matches environment name (dev/stage/prod)

## Resource Naming

All resources use a consistent naming pattern with random pet suffixes:
- Resource Group: `rg-<random-pet>`
- AKS Cluster: `aks-<random-pet>`
- DNS Prefix: `<random-pet>`

## Outputs

After deployment, Terraform provides:
- Cluster name and resource group
- kubectl configuration command
- ArgoCD port-forward command
- Random suffix for resource identification

## Clean Up

```bash
terraform destroy
```

## Next Steps

1. Set up the GitOps repository for application management
2. Configure ArgoCD applications for ingress, certificates, and DNS
3. Implement monitoring and logging solutions via GitOps
