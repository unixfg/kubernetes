#!/bin/bash

# Two-Stage AKS Deployment Script (split: 1-azure, 2-argocd)
# Runs Terraform in each subfolder to avoid state cycles and ignores the monolithic root.

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")" && pwd)
STACK_AZURE="$ROOT_DIR/1-azure"
STACK_ARGOCD="$ROOT_DIR/2-argocd"

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
terraform plan
echo ""
read -p "Continue with Stage 1 deployment? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Deployment cancelled."
    popd >/dev/null
    exit 1
fi

terraform apply -auto-approve
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
terraform plan
echo ""
read -p "Continue with Stage 2 deployment (ArgoCD)? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Stage 2 skipped. You can run it later from $STACK_ARGOCD."
    popd >/dev/null
    exit 0
fi

terraform apply -auto-approve

echo ""
read -p "Enable ApplicationSets now? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    terraform apply -auto-approve -var="enable_applicationsets=true"
fi

echo ""
echo "🎉 Deployment completed successfully!"
echo ""
echo "Next steps:"
echo "1. Add the SSH key to your GitOps repository (see terraform output)"
echo "2. Access ArgoCD UI: kubectl port-forward svc/argocd-server -n argocd 8080:80"
echo "3. Get ArgoCD password: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
popd >/dev/null
