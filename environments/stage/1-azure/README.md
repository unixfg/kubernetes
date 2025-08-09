# Stage 1-azure

This stack creates AKS and Azure Key Vault + SOPS integration, and prepares the cluster for use.

Usage:

- terraform init
- terraform apply

Outputs here are consumed by `../2-argocd` via local backend state file reference.
