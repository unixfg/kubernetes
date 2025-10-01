# Production Environment - 2-platform (K3s GitOps Platform)

This directory contains Terraform configuration for deploying the GitOps platform (ArgoCD + SOPS Operator) to a K3s cluster in the production environment.

## Key Differences from AKS Version

- **No Azure dependencies**: Removed Azure provider and AKS-specific configurations
- **GPG-based SOPS**: Uses `k3s-sops` module instead of `akv-sops` for GPG-based secret encryption
- **Direct kubeconfig**: Uses local kubeconfig context instead of Azure cluster credentials
- **Simplified setup**: No workload identity or Azure Key Vault dependencies

## Prerequisites

1. **K3s cluster running** with kubectl access configured
2. **GPG keys created** and stored in a Kubernetes secret
3. **Terraform configured** with appropriate kubeconfig

## Quick Start

```bash
# 1. Configure kubectl context for your K3s cluster
export KUBECONFIG=/path/to/your/k3s.yaml

# 2. Create GPG keys and secret (if not already done)
kubectl create secret generic sops-gpg-keys \
  --from-file=private.asc=path/to/private.key \
  --from-file=public.asc=path/to/public.key

# 3. Copy and customize terraform.tfvars
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your GPG fingerprint

# 4. Deploy the platform
terraform init
terraform plan -out main.tfplan
terraform apply main.tfplan
```

## Configuration

Update `terraform.tfvars` with your specific values:
- `gpg_fingerprint`: Your GPG key fingerprint
- `gpg_secret_name`: Name of the Kubernetes secret containing GPG keys
- `git_repo_url`: Your GitOps repository URL