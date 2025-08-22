# Kubernetes Infrastructure

This repository contains Terraform infrastructure code for deploying Azure Kubernetes Service (AKS) clusters with a complete GitOps platform including ArgoCD and SOPS secrets management.

## Architecture Overview

This infrastructure uses a **two-stage deployment** model that cleanly separates concerns and ensures proper dependency ordering:

### 🏗️ **Stage 1: Infrastructure (`1-azure`)**
- **AKS Cluster** with managed identity and RBAC
- **Azure Key Vault** for SOPS encryption with proper RBAC assignments
- **Core networking** and cluster bootstrap
- **No Kubernetes resources** - pure Azure infrastructure

### 🚀 **Stage 2: Platform (`2-platform`)**  
- **ArgoCD** GitOps controller for application management
- **SOPS Secrets Operator** for encrypted secrets decryption
- **ConfigMap** with current Key Vault URL for helper scripts
- **Platform readiness** - everything needed for applications

### 📱 **Stage 3: Applications (GitOps)**
- Applications deployed via ArgoCD ApplicationSets
- Secrets encrypted with SOPS and auto-decrypted by operator
- Complete separation from infrastructure concerns

## Repository Structure

```
kubernetes/
├── environments/
│   ├── stage/                    # Staging environment
│   │   ├── 1-azure/             # Azure infrastructure
│   │   │   ├── main.tf          # AKS + Key Vault + RBAC
│   │   │   ├── outputs.tf       # Cluster connection details
│   │   │   └── terraform.tfvars # Environment configuration
│   │   ├── 2-platform/          # GitOps platform
│   │   │   ├── main.tf          # ArgoCD + SOPS Operator
│   │   │   ├── outputs.tf       # Platform status
│   │   │   └── terraform.tfvars # Platform configuration  
│   │   └── README.md            # Environment-specific docs
│   └── modules/                 # Reusable Terraform modules
│       ├── aks/                 # AKS cluster module
│       ├── akv-sops/            # Key Vault + SOPS module
│       ├── argocd/              # ArgoCD module
│       └── naming/              # Consistent naming module
└── scripts/
    └── aks-helpers.sh           # Cluster management utilities
```

## Key Features

### 🔐 **Integrated Secrets Management**
- **SOPS encryption** with Azure Key Vault backend
- **Automatic decryption** in-cluster via sops-secrets-operator
- **Helper scripts** that auto-discover current Key Vault URL
- **Dual encryption** with PGP fallback for maximum resilience

### 🎯 **GitOps-First Design**
- **ArgoCD ApplicationSets** automatically discover and deploy applications
- **Environment-aware** application configuration
- **Complete separation** between platform and application concerns

### 🌱 **Redeploy Resilience** 
- **Random pet naming** ensures unique clusters for each deployment
- **No hardcoded values** in GitOps - everything discovered dynamically
- **Clean teardown** and rebuild capabilities

### ⚡ **Resource Optimization**
- **Right-sized resources** for cost efficiency
- **Multi-environment support** with environment-specific scaling
- **Efficient resource requests** that fit within node allocations

## Quick Start

### Prerequisites

- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli) installed and authenticated
- [Terraform](https://www.terraform.io/downloads.html) >= 1.0
- [kubectl](https://kubernetes.io/docs/tasks/tools/) for cluster access
- [SOPS](https://github.com/mozilla/sops) for secrets management
- [GPG](https://gnupg.org/) for PGP key management

### 🚀 **Direct Terraform Deployment**

```bash
# Clone repository
git clone <this-repository>
cd kubernetes/environments/stage

# Stage 1: Azure Infrastructure
cd 1-azure
terraform init
terraform plan -out main.tfplan
terraform apply main.tfplan

# Stage 2: GitOps Platform
cd ../2-platform
terraform init
terraform plan -out main.tfplan
terraform apply main.tfplan
```

This deployment approach gives you:
1. **Full visibility** into Terraform plans before applying
2. **Granular control** over each deployment stage
3. **Direct access** to Terraform state and operations
4. **Professional workflow** following standard Terraform practices

### 🔧 **Manual Deployment**

```bash
# Stage 1: Azure Infrastructure
cd kubernetes/environments/stage/1-azure
terraform init
terraform apply

# Stage 2: GitOps Platform  
cd ../2-platform
terraform init
terraform apply
```

### 📋 **Post-Deployment Steps**

```bash
# 1. Connect to cluster
az aks get-credentials --resource-group rg-<random-pet> --name aks-<random-pet>

# 2. Access ArgoCD
kubectl port-forward svc/argocd-server -n argocd 8080:80
# Open: http://localhost:8080
# User: admin
# Pass: kubectl -n argocd get secret argocd-initial-admin-secret -o go-template='{{printf "%s\n" (.data.password|base64decode)}}'

# 3. Configure SOPS encryption
source ../../gitops/scripts/sops-helpers.sh
sops-init  # Automatically uses current Key Vault URL

# 4. Deploy applications via ArgoCD ApplicationSets
```

## Environment Specifications

| Environment | Infrastructure | Platform | Use Case |
|-------------|---------------|----------|----------|
| **stage** | 3 nodes, Standard_B2ms | ArgoCD + SOPS | Pre-production validation |
| **dev** | 2 nodes, Standard_B2s | ArgoCD + SOPS | Development and testing |
| **prod** | 5 nodes, Standard_D2s_v3 | ArgoCD + SOPS | Production workloads |

## Secrets Management Workflow

### 🔑 **Initial Setup**
```bash
# Configure SOPS with current Key Vault (automatic)
sops-init

# Create encrypted secrets
sops-create --name my-secret --namespace my-app --env stage --key apiKey="secret-value"
```

### 🔄 **Development Workflow**  
```bash
# Edit encrypted secrets
sops-edit apps/secrets/overlays/stage/my-secret.enc.yaml

# Secrets automatically decrypt in-cluster via operator
# Applications reference standard Kubernetes secrets
```

### 🏗️ **Redeploy Scenarios**
```bash
# New cluster deployment
cd kubernetes/environments/stage/1-azure
terraform plan -out main.tfplan && terraform apply main.tfplan

cd ../2-platform
terraform plan -out main.tfplan && terraform apply main.tfplan

# Helper scripts automatically discover new vault URL
sops-init

# Re-encrypt existing secrets to new vault
sops-reencrypt apps/secrets/overlays/stage/
```

## Resource Naming

All resources use a consistent naming pattern with random pet suffixes:
- **Resource Group**: `rg-<random-pet>` (e.g., `rg-awaited-camel`)
- **AKS Cluster**: `aks-<random-pet>` (e.g., `aks-awaited-camel`)  
- **Key Vault**: `kv<randomstring>` (e.g., `kvawaitedcamel`)
- **DNS Prefix**: `<random-pet>` (e.g., `awaited-camel`)

## Integration with GitOps Repository

This infrastructure repository is designed to work with a separate GitOps repository:

- **Infrastructure Repo** (this): Manages AKS, Key Vault, ArgoCD, SOPS Operator
- **GitOps Repo**: Manages applications, ingress, certificates, DNS, and encrypted secrets

### ApplicationSet Configuration

ArgoCD is configured with ApplicationSets that automatically discover:
- **Helm applications**: `apps/*/helm/<env>/application.yaml`
- **Kustomize applications**: `apps/*/overlays/<env>/application.yaml`

## Outputs and Connection Details

After deployment, each stage provides:

### Stage 1 (Azure) Outputs:
- Cluster name and resource group
- Key Vault name and SOPS URL
- Cluster connection command

### Stage 2 (Platform) Outputs:
- ArgoCD port-forward command
- SOPS operator status
- ConfigMap creation confirmation
- Complete deployment summary

## Troubleshooting

### Common Issues

1. **SOPS decryption failures**: Check Key Vault RBAC assignments
2. **Resource constraints**: Adjust resource requests in platform components
3. **Application sync issues**: Verify ArgoCD ApplicationSet configuration

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

## Clean Up

```bash
# Destroy in reverse order
cd kubernetes/environments/stage/2-platform
terraform destroy

cd ../1-azure  
terraform destroy
```

## Next Steps

1. **Set up GitOps repository** with application manifests
2. **Configure ArgoCD ApplicationSets** for your application structure  
3. **Encrypt sensitive configuration** using SOPS
4. **Deploy applications** via GitOps and verify secret decryption
5. **Set up monitoring and logging** via GitOps applications
