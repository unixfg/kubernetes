# Stage 2-argocd

This stack deploys ArgoCD (GitOps controller) into the cluster created by `../1-azure`.

Prerequisites:
- Run `../1-azure` first so `../1-azure/terraform.tfstate` exists.

Usage:

- terraform init
- terraform apply
