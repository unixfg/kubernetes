#!/usr/bin/env bash

# Two-Stage AKS Deployment Script (split: 1-azure, 2-argocd)
# Runs Terraform in each subfolder to avoid state cycles and ignores the monolithic root.

set -euo pipefail


ROOT_DIR=$(cd "$(dirname "$0")" && pwd)
STACK_AZURE="$ROOT_DIR/1-azure"
STACK_ARGOCD="$ROOT_DIR/2-argocd"

# Reset state if requested
if [[ "${1:-}" == "reset" ]]; then
    echo "========================================================"
    echo "Terraform state backup and reset requested!"
    echo "========================================================"
    BACKUP_DIR="backup-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$ROOT_DIR/$BACKUP_DIR"
    
    for stack in "$STACK_AZURE" "$STACK_ARGOCD"; do
        stack_name=$(basename "$stack")
        echo "Backing up and clearing state in $stack..."
        
        # Backup state files if they exist
        if [[ -f "$stack/terraform.tfstate" ]]; then
            cp "$stack/terraform.tfstate" "$ROOT_DIR/$BACKUP_DIR/${stack_name}-terraform.tfstate"
        fi
        if [[ -f "$stack/terraform.tfstate.backup" ]]; then
            cp "$stack/terraform.tfstate.backup" "$ROOT_DIR/$BACKUP_DIR/${stack_name}-terraform.tfstate.backup"
        fi
        
        # Remove state files and terraform cache
        rm -f "$stack/terraform.tfstate" "$stack/terraform.tfstate.backup" "$stack/.terraform.lock.hcl"
        rm -rf "$stack/.terraform"
    done
    
    echo "✅ All Terraform state backed up to: $ROOT_DIR/$BACKUP_DIR"
    echo "✅ State files cleared for fresh deployment."
    exit 0
fi

# Avoid proxies interfering with AKS API or local connections
export NO_PROXY=localhost,127.0.0.1,::1,.azmk8s.io
export no_proxy="$NO_PROXY"

echo "========================================================"
echo "AKS Two-Stage Deployment Script"
echo "========================================================"

if [[ ! -d "$STACK_AZURE" || ! -d "$STACK_ARGOCD" ]]; then
    echo "❌ Expected subfolders not found:"
    echo "   - $STACK_AZURE"
    echo "   - $STACK_ARGOCD"
    exit 1
fi

echo ""
echo "Stage 1: Deploying AKS + Key Vault + SOPS (1-azure)"
echo ""

pushd "$STACK_AZURE" >/dev/null
terraform init -input=false
PLAN1="tfplan-stage1-$(date +%Y%m%d%H%M%S).bin"
terraform plan -out="$PLAN1"
echo ""
read -p "Continue with Stage 1 deployment? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Deployment cancelled."
    rm -f "$PLAN1"
    popd >/dev/null
    exit 1
fi

terraform apply "$PLAN1"
rm -f "$PLAN1"
popd >/dev/null

echo ""
echo "✅ Stage 1 completed successfully!"
echo ""
echo "========================================================"
echo "Stage 2: Deploy ArgoCD (2-argocd)"
echo "========================================================"
echo ""

pushd "$STACK_ARGOCD" >/dev/null
terraform init -input=false
PLAN2="tfplan-stage2-$(date +%Y%m%d%H%M%S).bin"
terraform plan -out="$PLAN2"
echo ""
read -p "Continue with Stage 2 deployment (ArgoCD)? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Stage 2 skipped. You can run it later from $STACK_ARGOCD."
    rm -f "$PLAN2"
    popd >/dev/null
    exit 0
fi

terraform apply "$PLAN2"
rm -f "$PLAN2"

echo ""
read -p "Enable ApplicationSets now? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    PLAN_APPS="tfplan-appsets-$(date +%Y%m%d%H%M%S).bin"
    terraform plan -out="$PLAN_APPS" -var="enable_applicationsets=true"
    terraform apply "$PLAN_APPS"
    rm -f "$PLAN_APPS"
fi

echo ""
echo "🎉 Deployment completed successfully!"
echo ""
echo "Next steps:"
echo "1. Add the SSH key to your GitOps repository (see terraform output)"
echo "2. Access ArgoCD UI: kubectl port-forward svc/argocd-server -n argocd 8080:80"
echo "3. Get ArgoCD password: kubectl -n argocd get secret argocd-initial-admin-secret -o go-template='{{printf "%s\n" (.data.password|base64decode)}}'
popd >/dev/null
