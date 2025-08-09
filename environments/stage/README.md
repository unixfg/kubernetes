# Kubernetes Environment (Stage)

This environment uses a split Terraform workflow:

- 1-azure: AKS + Azure Key Vault + SOPS and cluster bootstrap
- 2-argocd: ArgoCD GitOps controller

Use the `deploy.sh` script in this folder to run both stages. The previous monolithic Terraform in this directory has been removed.

Quick start:

```bash
bash deploy.sh
```

Manual runs:

```bash
cd 1-azure && terraform init && terraform apply
cd ../2-argocd && terraform init && terraform apply
```

ApplicationSets can be enabled at the end of Stage 2 via the prompt, or by applying with `-var="enable_applicationsets=true"` in `2-argocd`.
