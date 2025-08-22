# Stage 2-platform

This stack deploys the GitOps platform (ArgoCD + SOPS Secrets Operator) into the cluster created by `../1-azure`.

Prerequisites:
- Run `../1-azure` first so `../1-azure/terraform.tfstate` exists.

Usage:

- terraform init
- terraform apply
