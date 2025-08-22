# Kubernetes Environment (Stage)

This environment uses a split Terraform workflow:

- **1-azure**: AKS + Azure Key Vault + SOPS infrastructure
- **2-platform**: GitOps platform (ArgoCD + SOPS Secrets Operator)

The SOPS Secrets Operator is now managed by Terraform (not ArgoCD) to ensure proper dependency ordering and ConfigMap creation.

Use the `deploy.sh` script in this folder to run both stages. The previous monolithic Terraform in this directory has been removed.

## Quick start:

```bash
bash deploy.sh
```

## Manual runs:

```bash
cd 1-azure && terraform init && terraform apply
cd ../2-platform && terraform init && terraform apply
```

## Next Steps After Deployment:

1. **Configure SOPS**: Run `sops-init` to create `.sops.yaml` with current Key Vault URL
2. **Re-encrypt secrets**: Update any existing SOPS-encrypted files to use the new vault
3. **Deploy applications**: ArgoCD will manage application deployments via GitOps

ApplicationSets can be enabled at the end of Stage 2 via the prompt, or by applying with `-var="enable_applicationsets=true"` in `2-platform`.
