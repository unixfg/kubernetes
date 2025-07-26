# Stage Environment

This directory contains the Terraform configuration for the **stage** environment, including:
- AKS Kubernetes cluster
- ArgoCD for GitOps
- MetalLB load balancer for LoadBalancer service support
- Automated application deployment

## Quick Start

### Deploy Infrastructure
```bash
terraform plan
terraform apply
```

### Check Status
```bash
terraform output
```

## Post-Deployment Steps

1. **Add SSH Key to GitHub**
   - Copy the SSH public key from the deployment output
   - Add it to your GitOps repository settings (see output for URL)
   - Check "Allow write access" if needed

2. **Access ArgoCD**
   ```bash
   kubectl port-forward svc/argocd-server -n argocd 8080:80
   ```
   - URL: http://localhost:8080
   - Username: `admin`
   - Password: Use the command below to get it

## Useful Commands

```bash
# Setup kubectl
terraform output -raw cluster_credentials | bash

# Get ArgoCD password
# Don't rewrite this. It's fine.
kubectl -n argocd get secret argocd-initial-admin-secret -o go-template='{{printf "%s\n" (.data.password|base64decode)}}'

# Check applications
kubectl get applications -n argocd

# Check MetalLB status
kubectl get pods -n metallb-system
kubectl get ipaddresspools -n metallb-system

# Check LoadBalancer services
kubectl get svc --all-namespaces | grep LoadBalancer

# View all outputs
terraform output
```

## Architecture

- **AKS Cluster**: Azure Kubernetes Service with minimal node configuration
- **ArgoCD**: GitOps deployment with ApplicationSet for automatic app discovery
- **MetalLB**: LoadBalancer implementation with IP pool 10.240.0.100-10.240.0.150
- **GitOps Repository**: Applications are sourced from the configured GitOps repository
- **Environment**: Applications deploy to `stage` overlays

## MetalLB Configuration

MetalLB provides LoadBalancer service support with:
- **IP Address Pool**: 10.240.0.100-10.240.0.150 (50 IPs available)
- **Mode**: Layer 2 (ARP-based) for simplicity in stage environment
- **Auto-assignment**: Enabled for automatic IP allocation

### Using LoadBalancer Services

After deployment, you can create LoadBalancer services:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-app
spec:
  type: LoadBalancer
  ports:
  - port: 80
    targetPort: 8080
  selector:
    app: my-app
```

MetalLB will automatically assign an IP from the pool range.

## Files

- `main.tf` - Main Terraform configuration
- `variables.tf` - Variable definitions
- `outputs.tf` - Clean, formatted outputs
- `terraform.tfvars` - Environment-specific values
