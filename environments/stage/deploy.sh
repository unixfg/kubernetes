#!/bin/bash

# Two-Stage AKS Deployment Script
# This script automates the two-stage deployment process for AKS with ArgoCD

set -e

echo "========================================================"
echo "AKS Two-Stage Deployment Script"
echo "========================================================"

# Stage 1: Deploy infrastructure
echo ""
echo "Stage 1: Deploying AKS cluster and core infrastructure..."
echo "This includes: AKS, Key Vault, ArgoCD (without ApplicationSets)"
echo ""

terraform plan
echo ""
read -p "Continue with Stage 1 deployment? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Deployment cancelled."
    exit 1
fi

terraform apply

# Check if deployment was successful
if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Stage 1 completed successfully!"
    echo ""
    echo "========================================================"
    echo "Stage 2: Enabling ApplicationSets for GitOps"
    echo "========================================================"
    echo ""
    echo "This will enable ArgoCD to automatically discover and deploy"
    echo "applications from your GitOps repository."
    echo ""
    
    read -p "Continue with Stage 2 (enable ApplicationSets)? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Enabling ApplicationSets..."
        terraform apply -var="enable_applicationsets=true"
        
        if [ $? -eq 0 ]; then
            echo ""
            echo "🎉 Deployment completed successfully!"
            echo ""
            echo "Next steps:"
            echo "1. Add the SSH key to your GitOps repository (see terraform output)"
            echo "2. Access ArgoCD UI: kubectl port-forward svc/argocd-server -n argocd 8080:80"
            echo "3. Get ArgoCD password: kubectl -n argocd get secret argocd-initial-admin-secret -o go-template='{{printf \"%s\\n\" (.data.password|base64decode)}}'"
        else
            echo "❌ Stage 2 failed. Check the error messages above."
            exit 1
        fi
    else
        echo ""
        echo "Stage 2 skipped. You can enable ApplicationSets later by running:"
        echo "terraform apply -var=\"enable_applicationsets=true\""
    fi
else
    echo "❌ Stage 1 failed. Check the error messages above."
    exit 1
fi
