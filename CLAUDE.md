# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Kubernetes Infrastructure repository containing Terraform code for deploying Azure Kubernetes Service (AKS) clusters with a complete GitOps platform including ArgoCD and SOPS secrets management. The repository uses a **two-stage deployment model** that separates infrastructure concerns from platform concerns.

## Architecture

### Two-Stage Deployment Model
1. **Stage 1: Infrastructure (`1-azure/`)** - Pure Azure infrastructure: AKS cluster, Azure Key Vault, networking, RBAC
2. **Stage 2: Platform (`2-platform/`)** - GitOps platform: ArgoCD, SOPS Secrets Operator, ConfigMaps

### Key Components
- **AKS Module** (`modules/aks/`) - Managed AKS cluster with RBAC and networking
- **Azure Key Vault + SOPS Module** (`modules/akv-sops/`) - Secrets encryption backend
- **ArgoCD Module** (`modules/argocd/`) - GitOps controller for application management
- **Naming Module** (`modules/naming/`) - Consistent resource naming with random pet suffixes

## Common Commands

### Terraform Deployment
```bash
# Stage 1: Azure Infrastructure
cd environments/stage/1-azure
terraform init
terraform plan -out main.tfplan
terraform apply main.tfplan

# Stage 2: GitOps Platform
cd ../2-platform
terraform init
terraform plan -out main.tfplan
terraform apply main.tfplan
```

### AKS Management
```bash
# Source the helper functions
source scripts/aks-helpers.sh

# Get AKS credentials (automatic from terraform outputs)
aks-creds environments/stage/1-azure

# List available clusters
aks-list

# Show current kubectl context
aks-context
```

### Post-Deployment Access
```bash
# ArgoCD access
kubectl port-forward svc/argocd-server -n argocd 8080:80
# URL: http://localhost:8080
# User: admin
# Password: kubectl -n argocd get secret argocd-initial-admin-secret -o go-template='{{printf "%s\n" (.data.password|base64decode)}}'
```

## Important Patterns

### Resource Naming Convention
- All resources use random pet suffixes for uniqueness and redeploy resilience
- **Resource Group**: `rg-<random-pet>` (e.g., `rg-awaited-camel`)
- **AKS Cluster**: `aks-<random-pet>` (e.g., `aks-awaited-camel`)
- **Key Vault**: `kv<randomstring>` (e.g., `kvawaitedcamel`)

### Module Dependencies
- `modules/naming/` must be called first in all deployments
- `modules/akv-sops/` provides Key Vault backend for SOPS encryption
- `modules/argocd/` depends on cluster being available and configured

### Environment Structure
Each environment (stage, dev, prod) follows the same pattern:
- `1-azure/` - Infrastructure layer with `main.tf`, `outputs.tf`, `variables.tf`
- `2-platform/` - Platform layer with same structure
- Terraform state is isolated per stage per environment

## Secrets Management with SOPS

This repository is designed to work with SOPS for encrypted secrets management:
- Azure Key Vault provides encryption backend
- SOPS Secrets Operator handles automatic in-cluster decryption
- Helper scripts auto-discover current Key Vault URL for portability
- Dual encryption with PGP fallback for resilience

## GitOps Integration

The infrastructure deploys ArgoCD configured with ApplicationSets that automatically discover:
- **Helm applications**: `apps/*/helm/<env>/application.yaml`
- **Kustomize applications**: `apps/*/overlays/<env>/application.yaml`

This repository manages infrastructure; applications are deployed from a separate GitOps repository.

## Troubleshooting

### Common Issues
- **SOPS decryption failures**: Check Key Vault RBAC assignments in `modules/akv-sops/`
- **Resource constraints**: Adjust resource requests in `modules/argocd/`
- **Application sync issues**: Verify ArgoCD ApplicationSet configuration

### Helper Commands
```bash
# Check platform status
kubectl get all -n argocd
kubectl get all -n sops-secrets-operator

# Check secrets decryption
kubectl get sopssecrets -A

# View operator logs
kubectl logs -n sops-secrets-operator deploy/sops-secrets-operator
```

## Development Workflow

1. Always deploy Stage 1 before Stage 2 (dependencies)
2. Use `terraform plan -out` for safe deployments
3. Use helper scripts in `scripts/aks-helpers.sh` for cluster access
4. Test changes in staging environment first
5. Destroy in reverse order: Stage 2, then Stage 1