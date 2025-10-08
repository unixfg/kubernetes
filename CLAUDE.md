# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Kubernetes Infrastructure repository containing Terraform code for deploying both Azure Kubernetes Service (AKS) and K3s clusters with a complete GitOps platform including ArgoCD and SOPS secrets management. The repository uses a **two-stage deployment model** that separates infrastructure concerns from platform concerns.

## Architecture

### Dual Platform Support
The repository supports two Kubernetes platforms:
- **AKS (Azure)**: Full Azure-managed Kubernetes with Azure Key Vault for SOPS encryption
- **K3s (Bare Metal/VM)**: Lightweight Kubernetes with GPG-based SOPS encryption

### Two-Stage Deployment Model
1. **Stage 1: Infrastructure (`1-azure/`)** - Azure-only: AKS cluster, Azure Key Vault, networking, RBAC
2. **Stage 2: Platform (`2-platform/`)** - Platform layer: ArgoCD, SOPS Secrets Operator, ConfigMaps

### Key Modules
- **AKS Module** (`modules/aks/`) - Managed AKS cluster with RBAC and networking
- **Azure Key Vault + SOPS Module** (`modules/akv-sops/`) - Azure Key Vault backend for SOPS encryption
- **K3s SOPS Module** (`modules/k3s-sops/`) - GPG-based SOPS for K3s clusters
- **ArgoCD Module** (`modules/argocd/`) - GitOps controller with automatic application discovery
- **Naming Module** (`modules/naming/`) - Consistent resource naming with random pet suffixes

## Environment Structure

### AKS Environments (stage)
```
environments/stage/
├── 1-azure/          # Azure infrastructure (AKS, Key Vault, networking)
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── terraform.tfvars
└── 2-platform/       # GitOps platform (ArgoCD, SOPS Operator)
    ├── main.tf
    ├── variables.tf
    ├── outputs.tf
    └── terraform.tfvars
```

### K3s Environments (prod)
```
environments/prod/
└── 2-platform/       # GitOps platform only (no Azure stage)
    ├── main.tf
    ├── variables.tf
    ├── outputs.tf
    ├── terraform.tfvars
    └── terraform-with-gpg.sh  # Helper for GPG key injection
```

## Common Commands

### AKS Deployment (stage)
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

# Get AKS credentials (using helper script)
source scripts/aks-helpers.sh
aks-creds environments/stage/1-azure
```

### K3s Deployment (prod)
```bash
# Ensure kubectl is configured for K3s cluster
export KUBECONFIG=/path/to/k3s.yaml

# Deploy platform with GPG keys
cd environments/prod/2-platform
./terraform-with-gpg.sh plan -out main.tfplan
./terraform-with-gpg.sh apply main.tfplan
```

### ArgoCD Access
```bash
# Port forward to ArgoCD UI
kubectl port-forward svc/argocd-server -n argocd 8080:80

# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o go-template='{{printf "%s\n" (.data.password|base64decode)}}'

# Access UI at http://localhost:8080
```

## Critical Patterns

### ArgoCD GitHub App Authentication
The ArgoCD module supports GitHub App authentication for private repositories:
- GitHub App credentials must be provided via environment variable `TF_VAR_github_app_private_key`
- The private key file is typically stored at `~/infrastructure/github.key`
- Set `use_github_app = true` and `use_ssh_for_git = false` in terraform.tfvars
- Repository secret is created automatically with App ID, Installation ID, and private key

### SOPS Encryption - Dual Backend Support

**AKS (Azure Key Vault)**:
- `modules/akv-sops/` creates Azure Key Vault and RBAC assignments
- SOPS operator uses workload identity to access Key Vault
- Automatic key rotation and managed identities

**K3s (GPG)**:
- `modules/k3s-sops/` uses GPG keys for encryption
- GPG keys must be provided via environment variables or existing Kubernetes secret
- Helper script `terraform-with-gpg.sh` exports GPG keys from local keyring
- Keys are base64-encoded and injected into `sops-gpg-keys` secret

### DNS Resolution (ndots) Configuration
The ArgoCD module sets `dnsConfig.options.ndots=1` for both repoServer and applicationSet pods to prevent DNS resolution issues. This is critical when using custom DNS/search domains to avoid incorrect FQDN resolution (e.g., `api.github.com` resolving to `api.github.com.doesthings.online`).

### ApplicationSet Auto-Discovery
ArgoCD automatically discovers applications via ApplicationSets:
- **Kustomize apps**: `apps/*/overlays/<env>` or `gitops/apps/*/overlays/<env>`
- **Helm apps**: `apps/*/helm/<env>/application.yaml` or `gitops/apps/*/helm/<env>/application.yaml`
- Application names are derived from directory structure (no environment suffix)
- Namespace is set to match application name

### Resource Naming with Random Suffixes
All Azure resources use random pet naming for uniqueness:
- **Resource Group**: `rg-<random-pet>` (e.g., `rg-awaited-camel`)
- **AKS Cluster**: `aks-<random-pet>`
- **Key Vault**: `kv<randomstring>` (e.g., `kvawaitedcamel`)
- This allows clean cluster recreation without naming conflicts

### Module Dependencies
- `modules/naming/` must be called first in Azure deployments
- `modules/akv-sops/` or `modules/k3s-sops/` provides SOPS encryption backend
- `modules/argocd/` depends on cluster being available and configured
- Platform (2-platform) always depends on infrastructure (1-azure for AKS)

### Terraform State Management
- State is isolated per stage per environment
- AKS: Separate state files for 1-azure and 2-platform
- K3s: Single state file for 2-platform only
- Always destroy in reverse order: 2-platform, then 1-azure (if applicable)

## Important Configuration Files

### terraform.tfvars Keys
**AKS (stage)**:
- `resource_group_location`, `node_count`, `vm_size` - Infrastructure sizing
- `git_repo_url`, `use_ssh_for_git` - Git repository configuration
- `argocd_chart_version` - ArgoCD version pinning

**K3s (prod)**:
- `environment = "prod"` - Environment identifier
- `gpg_fingerprint` - GPG key for SOPS encryption
- `use_github_app = true` - Enable GitHub App authentication
- `github_app_id`, `github_app_installation_id` - GitHub App credentials
- `enable_applicationsets = false` - Set during initial deployment, then `true`

### GitHub App Private Key
For K3s deployments using GitHub App authentication:
```bash
export TF_VAR_github_app_private_key="$(cat ~/infrastructure/github.key)"
./terraform-with-gpg.sh apply -auto-approve
```

### GPG Key Management (K3s)
The `terraform-with-gpg.sh` script automatically exports GPG keys:
- Reads GPG key ID from script (hardcoded)
- Exports private and public keys as base64-encoded armor
- Sets `TF_VAR_gpg_private_key_content` and `TF_VAR_gpg_public_key_content`
- Terraform creates `sops-gpg-keys` secret in cluster

## Deployment Workflow

### Initial AKS Deployment
1. Deploy infrastructure: `cd environments/stage/1-azure && terraform apply`
2. Deploy platform: `cd ../2-platform && terraform apply`
3. Get cluster credentials: `source scripts/aks-helpers.sh && aks-creds`
4. Verify ArgoCD: `kubectl get pods -n argocd`

### Initial K3s Deployment
1. Set `enable_applicationsets = false` in terraform.tfvars
2. Run: `./terraform-with-gpg.sh apply -auto-approve`
3. Verify ArgoCD installation: `kubectl get pods -n argocd`
4. Set `enable_applicationsets = true` in terraform.tfvars
5. Run: `./terraform-with-gpg.sh apply -auto-approve`
6. Verify applications discovered: `kubectl get applications -n argocd`

### Why Two-Stage ApplicationSet Creation (K3s)
ApplicationSet CRDs must exist before creating ApplicationSet resources. During initial deployment, ArgoCD Helm chart hasn't installed CRDs yet, so terraform plan fails. Setting `enable_applicationsets = false` allows ArgoCD to install first, then `enable_applicationsets = true` creates the ApplicationSets.

### Redeployment from Snapshot/Restore
When restoring K3s nodes from snapshot:
1. All Kubernetes resources are deleted
2. Run full platform deployment: `./terraform-with-gpg.sh apply -auto-approve`
3. Terraform will recreate all namespaces, secrets, and Helm releases
4. ArgoCD will automatically sync applications

## Troubleshooting

### ArgoCD Repository Authentication Issues
**Symptom**: "authentication required: Repository not found" in repo-server logs

**Cause**: GitHub App private key not set or empty in secret

**Fix**:
```bash
# Verify secret has private key
kubectl describe secret argocd-repo-github-app -n argocd

# If githubAppPrivateKey shows 0 bytes, re-apply with key:
export TF_VAR_github_app_private_key="$(cat ~/infrastructure/github.key)"
./terraform-with-gpg.sh apply -auto-approve

# Restart ArgoCD components
kubectl rollout restart deployment/argocd-repo-server -n argocd
kubectl rollout restart deployment/argocd-applicationset-controller -n argocd
```

### ApplicationSet CRD Not Found
**Symptom**: `terraform plan` fails with "no matches for kind 'ApplicationSet'"

**Cause**: ArgoCD not yet deployed or CRDs not installed

**Fix**: Set `enable_applicationsets = false`, deploy ArgoCD first, then set to `true`

### SOPS Decryption Failures (AKS)
**Issue**: Check Key Vault RBAC assignments in `modules/akv-sops/`

**Commands**:
```bash
kubectl logs -n sops-secrets-operator deploy/sops-secrets-operator
kubectl get sopssecrets -A
```

### SOPS Decryption Failures (K3s)
**Issue**: GPG keys not properly loaded in secret

**Commands**:
```bash
kubectl get secret sops-gpg-keys -n sops-secrets-operator -o yaml
kubectl logs -n sops-secrets-operator deploy/sops-secrets-operator
```

### Kyverno Admission Webhooks Blocking Installation
**Symptom**: Helm installs timing out or failing pre-install hooks

**Cause**: Kyverno admission webhooks are active but controller is crashed

**Fix**:
```bash
# Delete blocking webhooks
kubectl delete validatingwebhookconfigurations kyverno-cleanup-validating-webhook-cfg kyverno-ttl-validating-webhook-cfg

# Retry deployment
./terraform-with-gpg.sh apply -auto-approve
```

### DNS Resolution Issues
**Symptom**: ArgoCD cannot reach api.github.com or other external services

**Cause**: High ndots value with search domains causing incorrect FQDN resolution

**Fix**: Already configured in module with `dnsConfig.options.ndots=1` for ArgoCD pods

## GitOps Integration

ArgoCD manages applications from a separate GitOps repository with automatic discovery patterns:
- Applications deploy to namespace matching app name
- Supports both Kustomize overlays and Helm charts
- SOPS-encrypted secrets automatically decrypted by operator
- Sync policies configured per environment (auto-sync in prod)

## Helper Scripts

### AKS Helpers (`scripts/aks-helpers.sh`)
```bash
source scripts/aks-helpers.sh

aks-creds <path-to-terraform-dir>  # Get cluster credentials from outputs
aks-list                            # List all AKS clusters
aks-context                         # Show current kubectl context
```

### GPG Terraform Helper (`terraform-with-gpg.sh`)
```bash
./terraform-with-gpg.sh plan        # Plan with GPG keys injected
./terraform-with-gpg.sh apply       # Apply with GPG keys injected
```
