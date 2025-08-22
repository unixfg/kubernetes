# Agent Operating Instructions for Kubernetes Repository

This document provides practical operating instructions for ### **3. Verify Key Vault Access**
If seeing 403 errors, extract the identity from operator logs:
```bash
# Extract application ID from error logs
kubectl logs -n sops-secrets-operator deploy/sops-secrets-operator --tail=50 | \
  grep -o 'appid=[0-9a-f\-]*' | head -1
```

**Identity Resolution Process:**
1. **Error Analysis:** 403 Forbidden errors contain the actual calling identity (appid)
2. **Identity Mismatch:** The runtime identity may differ from expected kubelet identity
3. **RBAC Grant:** Must grant Key Vault access to the specific identity found in error logs

**Safe RBAC Assignment:**
```bash
# Verify vault exists before role assignment
az keyvault show --name <vault-name> --query id -o tsv && \
  az role assignment create \
    --assignee <appid-from-logs> \
    --role "Key Vault Crypto User" \
    --scope /subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.KeyVault/vaults/<vault-name> || \
  echo "Vault verification failed - check vault name and permissions"
```king with this specific Kubernetes infrastructure repository.

---

## 📁 **Repository Structure and Navigation**

### **Two-Stage Terraform Architecture**
```
kubernetes/environments/stage/
├── 1-azure/           # Infrastructure layer (AKS, Key Vault, RBAC)
└── 2-platform/        # Platform layer (ArgoCD, SOPS operator)
```

### **GitOps Application Management**
```
gitops/apps/
├── external-dns/      # DNS automation
├── hello-nginx/       # Sample workload with overlays
├── rook-ceph/         # Storage platform
├── secrets/           # SOPS encrypted secrets
└── traefik/           # Ingress controller
```

### **Key Files to Know**
- `gitops/scripts/sops-helpers.sh` - SOPS management functions
- `kubernetes/README.md` - Deployment procedures
- `gitops/.sops.yaml` - Encryption configuration

---

## 🚀 **Common Operations**

### **Initial Deployment**
Execute Terraform deployments in the correct order:
```bash
# Stage 1: Infrastructure foundation
cd kubernetes/environments/stage/1-azure
terraform plan -out main.tfplan
terraform apply main.tfplan

# Stage 2: Platform layer
cd ../2-platform
terraform plan -out main.tfplan
terraform apply main.tfplan
```

**Deployment Architecture:**
- **Stage 1:** Pure Azure infrastructure (AKS cluster, Key Vault, managed identities)
- **Stage 2:** Platform controllers (ArgoCD, SOPS operator) with service discovery ConfigMaps
- **Automatic Integration:** Stage 2 consumes Stage 1 outputs via Terraform data sources

**Validation Checklist:**
1. ✅ AKS cluster accessible: `kubectl cluster-info`
2. ✅ ArgoCD running: `kubectl get pods -n argocd`
3. ✅ SOPS operator running: `kubectl get pods -n sops-secrets-operator`
4. ✅ ConfigMap created: `kubectl get configmap sops-workload-identity -n sops-secrets-operator`

### **Working with Secrets**
```bash
# Source helper functions (prerequisite for all SOPS operations)
source gitops/scripts/sops-helpers.sh

# Initialize SOPS configuration (discovers vault URL from cluster ConfigMap)
sops-init
```

**SOPS Configuration Discovery:**
The `sops-init` function queries the cluster's `sops-workload-identity` ConfigMap to get the current Key Vault URL. This eliminates hardcoded URLs that break when clusters are redeployed with new random pet names.

**Secret Operations:**
```bash
# Edit encrypted secrets using SOPS
sops gitops/apps/secrets/overlays/stage/external-dns-ns1-secret.enc.yaml

# Verify secret decryption status in cluster
kubectl get sopssecrets -A
kubectl describe sopssecret external-dns-ns1-api-key-stage -n external-dns
```

**Authentication Flow:**
1. **SOPS Operator:** Uses AKS kubelet managed identity (no additional credentials required)
2. **Key Vault Access:** Kubelet identity has "Key Vault Crypto User" role assigned via Terraform
3. **Secret Creation:** Operator decrypts SOPS files and creates corresponding Kubernetes secrets

### **ArgoCD Application Management**
```bash
# Retrieve ArgoCD admin password for UI access
kubectl get secret argocd-initial-admin-secret -n argocd \
  -o jsonpath='{.data.password}' | base64 -d

# Create secure tunnel to ArgoCD UI
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Monitor application synchronization status
kubectl get applications -n argocd
```

**ArgoCD Authentication:**
- **Admin Account:** Uses generated password stored in `argocd-initial-admin-secret`
- **RBAC Integration:** ArgoCD integrates with Kubernetes RBAC for fine-grained permissions
- **TLS Termination:** Internal TLS certificates managed by ArgoCD for secure communication

**Application Discovery:**
ArgoCD uses ApplicationSet with automatic discovery pattern that scans the GitOps repository structure and creates applications based on directory organization.

---

## 🔧 **Troubleshooting Workflows**

### **SOPS Secrets Not Decrypting**

**1. Check Operator Status**
```bash
kubectl get pods -n sops-secrets-operator
kubectl logs -n sops-secrets-operator deploy/sops-secrets-operator --tail=50
```

**2. Check ConfigMap**
```bash
kubectl get configmap sops-workload-identity -n sops-secrets-operator -o yaml
```

**3. Verify Key Vault Access**
If seeing 403 errors, extract the identity from logs:
```bash
# Look for lines like: Caller: appid=9ce2c654-e63d-4520-9520-440fc1edec2c
# Grant Key Vault access to that specific identity:
az role assignment create \
  --assignee <appid-from-logs> \
  --role "Key Vault Crypto User" \
  --scope /subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.KeyVault/vaults/<vault-name>
```

### **Resource Scheduling Issues**

**Check Cluster Capacity:**
```bash
kubectl top nodes
kubectl describe nodes | grep -A 5 "Allocated resources"
```

**For CPU/Memory Constraints:**
- SOPS operator typically needs: 50m CPU, 64Mi memory (reduced for cluster density)
- Check Helm values in `2-platform/main.tf` for resource adjustments

### **ArgoCD Sync Failures**

**Common Issues:**
- Never use `HEAD` as target revision - causes sync problems
- Check for stuck operations: `kubectl get applications -n argocd`
- Clear stuck state: `kubectl patch application <app-name> -n argocd --type=merge -p='{"operation":null}'`

---

## ⚙️ **Configuration Patterns**

### **Service Discovery Pattern**
This repository implements ConfigMap-based service discovery to eliminate hardcoded values:

**Terraform Implementation:**
```hcl
resource "kubernetes_config_map" "sops_workload_identity" {
  data = {
    key_vault_url = module.akv_sops.sops_azure_kv_url  # Dynamic from current deployment
  }
}
```

**Helper Script Integration:**
```bash
get_sops_key_vault_url() {
    kubectl get configmap sops-workload-identity -n sops-secrets-operator \
        -o jsonpath='{.data.key_vault_url}' 2>/dev/null
}
```

**Why Service Discovery:**
- **Random Pet Names:** Azure resources use random pet names that change on redeploy
- **Redeploy Resilience:** ConfigMaps contain current deployment's resource URLs
- **No Hardcoding:** Helper scripts dynamically discover current configuration
- **State Independence:** Applications don't need to know infrastructure details

### **Two-Stage Dependency Management**

**Stage 1 (1-azure) - Infrastructure Foundation:**
- Pure Azure resource provisioning (AKS cluster, Key Vault, networking)
- Managed identity creation and RBAC assignments
- No Kubernetes resource deployment
- Outputs: cluster connection details, Key Vault URLs, identity information

**Stage 2 (2-platform) - Platform Layer:**
- Consumes Stage 1 outputs via Terraform data sources for loose coupling
- Deploys platform controllers (ArgoCD for GitOps, SOPS operator for secrets)
- Creates service discovery ConfigMaps with current deployment information
- Establishes platform readiness for application deployment

**Architecture Benefits:**
- **Clean Dependency Order:** Infrastructure → Platform → Applications (via GitOps)
- **No Circular References:** Each stage has clear inputs and outputs
- **Independent Lifecycle:** Stages can be managed and versioned separately
- **Testable Layers:** Each stage can be validated independently before proceeding

---

## 🎯 **Agent Operating Principles**

### **1. Layer-by-Layer Validation**
Never skip validation steps:
1. ✅ Infrastructure accessible
2. ✅ Platform controllers running  
3. ✅ Applications can sync

### **2. Error Message Forensics**
Extract actionable information from errors:
- **Identity IDs**: `appid=9ce2c654...` → grant specific RBAC
- **Resource names**: Use exact namespace/name from errors
- **API versions**: Check for deprecated resources

### **3. Capacity-Aware Operations**
This cluster operates at 96%+ CPU utilization with resource constraints:

**Resource Monitoring:**
```bash
# Check current node utilization before deploying
kubectl top nodes
kubectl describe nodes | grep -A 5 "Allocated resources"
```

**Resource Right-Sizing Strategy:**
- **SOPS Operator:** Configured with 50m CPU requests (reduced from standard 100m)
- **Memory Optimization:** 64Mi requests vs standard 128Mi for cluster density
- **Scheduling Awareness:** Monitor `FailedScheduling` events for capacity issues

**Why Conservative Sizing:**
The cluster runs many small workloads efficiently rather than fewer large ones. Resource requests are sized for actual workload needs, not theoretical maximums, to maximize cluster density.

### **4. State Management Strategy**
- **Local Terraform state** for environment isolation and simplified collaboration
- **Import existing resources** when transitioning management: `terraform import <resource.name> <resource-id>`
- **Data source coupling** between Terraform stacks instead of shared state files
- **Stack separation** by lifecycle: infrastructure vs platform vs application concerns

**State Transition Patterns:**
When moving resources between management systems (ArgoCD → Terraform), use import operations to maintain resource continuity rather than destroy/recreate cycles.

### **5. GitOps Boundaries**
- **Infrastructure (Terraform):** Identity management, RBAC, platform controllers that applications depend on
- **Platform (Terraform):** Service discovery, operators, cross-cutting concerns like secrets management
- **Applications (ArgoCD):** Business logic, application configuration, runtime behavior and scaling

**Boundary Rationale:**
- **Platform Dependencies:** Applications need secrets operator running before they can consume encrypted secrets
- **Identity Management:** Infrastructure layer handles all Azure identity and RBAC complexity
- **State Separation:** Different lifecycles require different management approaches

---

## 🔍 **Essential Commands**

### **Deployment Operations**
```bash
# Two-stage deployment workflow
cd kubernetes/environments/stage/1-azure
terraform plan -out main.tfplan && terraform apply main.tfplan

cd ../2-platform  
terraform plan -out main.tfplan && terraform apply main.tfplan

# Individual Terraform operations within stack directories
terraform plan -out main.tfplan      # Preview changes
terraform apply main.tfplan          # Apply planned changes
terraform destroy -auto-approve      # Clean environment

# Terraform state inspection
terraform state list                 # List managed resources
terraform show <resource-name>       # Show resource details
```

**Safe Cleanup Operations:**
```bash
# Remove Terraform plan files safely
[ -f main.tfplan ] && rm main.tfplan || echo "No plan file to remove"

# Clean backup state files with verification
[ -f terraform.tfstate.backup ] && \
  [ -f terraform.tfstate ] && \
  rm terraform.tfstate.backup || \
  echo "Backup cleanup skipped - primary state missing"
```

### **Kubernetes Diagnostics**
```bash
# Cluster capacity and resource usage
kubectl top nodes
kubectl describe nodes | grep -A 5 "Allocated resources"

# Pod troubleshooting
kubectl get pods -A | grep -v Running
kubectl describe pod <pod-name> -n <namespace>
kubectl logs <pod-name> -n <namespace> --tail=50

# Secret decryption status
kubectl get sopssecrets -A
kubectl get secrets -A | grep -E "(external-dns|traefik)"
```

### **Azure Operations**
```bash
# Configure cluster credentials for kubectl access
az aks get-credentials --resource-group rg-awaited-camel --name aks-awaited-camel

# Key Vault discovery and management
az keyvault list --query "[].{Name:name,ResourceGroup:resourceGroup}" -o table
az role assignment list --scope <vault-resource-id> --output table

# Safe identity-based RBAC assignment with verification
az keyvault show --name <vault-name> --query id -o tsv && \
  az role assignment create \
    --assignee <appid> \
    --role "Key Vault Crypto User" \
    --scope <vault-resource-id> || \
  echo "RBAC assignment failed - verify vault exists and permissions"
```

**Azure Authentication Context:**
- **AKS Integration:** Cluster uses managed identity for Azure service authentication
- **Key Vault Access:** RBAC-based access control instead of access policies for modern security
- **Identity Discovery:** Runtime identities may differ from expected - use error logs for accuracy

### **SOPS Operations**
```bash
# Source helper functions (always prerequisite)
source gitops/scripts/sops-helpers.sh

# Initialize SOPS configuration with current cluster context
sops-init

# Edit encrypted secrets using SOPS editor
sops gitops/apps/secrets/overlays/stage/<secret-file>.enc.yaml

# Re-encrypt all secrets with current vault configuration
find gitops/apps/secrets/overlays/stage -name "*.enc.yaml" -exec sops updatekeys {} \;
```

**SOPS Integration Details:**
- **Dual Encryption:** Files encrypted to both Azure Key Vault and PGP for redundancy
- **Helper Integration:** `sops-init` discovers current Key Vault URL from cluster ConfigMap
- **Atomic Operations:** SOPS handles encryption/decryption atomically to prevent corruption
- **Version Compatibility:** Operator and CLI versions must be compatible for successful decryption

---

## ⚠️ **Critical Warnings**

### **Don't Do These Things**
- ❌ Never run git commands; all commits are handled in vscode
- ❌ Never use `HEAD` as ArgoCD target revision
- ❌ Never hardcode random pet names (like vault URLs) in GitOps manifests  
- ❌ Never deploy SOPS secrets without ensuring the operator is running first
- ❌ Never ignore resource constraints - check cluster capacity first
- ❌ Never skip the ConfigMap prerequisite for SOPS operations

### **Required Prerequisites**
- ✅ Azure CLI authenticated
- ✅ kubectl configured for cluster
- ✅ Terraform in PATH
- ✅ SOPS binary installed
- ✅ Helper functions sourced: `source gitops/scripts/sops-helpers.sh`

---

## 🎯 **Quick Reference Card**

### **When Things Break**
1. **Check operator logs first**: `kubectl logs -n sops-secrets-operator deploy/sops-secrets-operator`
2. **Verify ConfigMap exists**: `kubectl get configmap sops-workload-identity -n sops-secrets-operator`
3. **Check resource capacity**: `kubectl top nodes`
4. **Extract identity from 403 errors**: Look for `appid=` in logs
5. **Grant specific RBAC**: Use the exact appid from error logs

### **Deployment Order**
1. **Infrastructure Deployment:** `cd kubernetes/environments/stage/1-azure && terraform plan -out main.tfplan && terraform apply main.tfplan`
2. **Platform Deployment:** `cd ../2-platform && terraform plan -out main.tfplan && terraform apply main.tfplan` 
3. **Application Sync:** ArgoCD automatically discovers and syncs applications from GitOps repository

**Dependency Chain Rationale:**
- **Stage 1 Prerequisites:** AKS cluster must exist before deploying any Kubernetes resources
- **Stage 2 Prerequisites:** Platform controllers (ArgoCD, SOPS operator) must be running before applications can sync
- **Application Prerequisites:** Applications requiring secrets need SOPS operator healthy before deployment

**Direct Terraform Benefits:**
- **Full Control:** See exact Terraform plan before applying changes
- **Granular Operations:** Apply, destroy, or modify individual stacks as needed
- **State Visibility:** Direct access to Terraform state and resource inspection
- **Debugging Capability:** Investigate specific resource configurations and dependencies

### **File Locations**
- Encrypted secrets: `gitops/apps/secrets/overlays/stage/*.enc.yaml`
- SOPS config: `gitops/.sops.yaml` 
- Helper functions: `gitops/scripts/sops-helpers.sh`
- Terraform stacks: `kubernetes/environments/stage/{1-azure,2-platform}/`

This document provides the essential operating knowledge for working effectively with this Kubernetes repository's specific architecture and constraints.
