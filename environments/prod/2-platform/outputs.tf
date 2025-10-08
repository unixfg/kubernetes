# Prod 2-platform Outputs (GitOps Platform: ArgoCD + SOPS Operator for K3s)

# GitOps and Repository Access
output "argocd_repo_public_key" {
  description = "Public SSH key for ArgoCD to access private config repo"
  value       = trimspace(module.argocd.argocd_repo_public_key)
}

output "argocd_port_forward_command" {
  description = "Command to access ArgoCD via HTTP port forwarding"
  value       = module.argocd.argocd_port_forward_command
}

# SOPS Configuration Outputs
output "sops_operator_status" {
  description = "SOPS Secrets Operator deployment status"
  value       = "SOPS Secrets Operator managed by ArgoCD in namespace 'sops-secrets-operator'"
}

output "age_public_key" {
  description = "Age public key used for SOPS encryption"
  value       = module.k3s_sops.age_public_key
}

output "sops_configuration" {
  description = "SOPS configuration for GitOps"
  value       = module.k3s_sops.sops_configuration
}

# User-Friendly Deployment Summary
output "deployment_summary" {
  description = "Deployment summary for K3s environment"
  value = <<-EOT

    🚀 ${title(local.environment_name)} Environment GitOps Platform Ready! (K3s)

    Platform Components:
      ✅ ArgoCD (GitOps Controller) - namespace: ${module.argocd.argocd_namespace}
      ✅ SOPS Secrets Operator - namespace: sops-secrets-operator (managed by ArgoCD)
      ✅ K3s SOPS Module - GPG-based encryption configured

    Access ArgoCD:
      ${module.argocd.argocd_port_forward_command}
      Open: http://localhost:8080
      User: admin
      Pass: kubectl -n argocd get secret argocd-initial-admin-secret -o go-template='{{printf "%s\n" (.data.password|base64decode)}}'

    Add deploy key to GitHub:
      ${trimspace(module.argocd.argocd_repo_public_key)}
      → ${replace(var.git_repo_url, ".git", "")}/settings/keys

    SOPS Configuration:
      Age Public Key: ${module.k3s_sops.age_public_key}
      Encrypt secrets: sops -e --age ${module.k3s_sops.age_public_key} secret.yaml > secret.enc.yaml

    Next Steps:
      • Age key is automatically created from Terraform variables
      • Encrypt secrets using the provided GPG fingerprint
      • Deploy applications via ArgoCD
  EOT
}

# Quick reference commands
output "commands" {
  description = "Quick command reference for K3s"
  value = <<-EOT

    kubectl get applications -n argocd    # Check deployed apps
    kubectl get pods --all-namespaces     # Check all pods
    kubectl get svc --all-namespaces      # Check all services
    kubectl get secret sops-age -n sops-secrets-operator  # Check Age secret
    terraform output -raw argocd_repo_public_key  # Get SSH key
  EOT
}

# Useful commands reference
output "useful_commands" {
  description = "Useful commands reference for K3s"
  value = {
    access_argocd        = module.argocd.argocd_port_forward_command
    get_argocd_password  = "kubectl -n argocd get secret argocd-initial-admin-secret -o go-template='{{printf \"%s\\n\" (.data.password|base64decode)}}'"
    check_applications   = "kubectl get applications -n ${module.argocd.argocd_namespace}"
    view_ssh_key         = "terraform output -raw argocd_repo_public_key"
    check_age_secret     = "kubectl get secret sops-age -n sops-secrets-operator"
    sops_encrypt_command = "sops -e --age ${module.k3s_sops.age_public_key} secret.yaml > secret.enc.yaml"
    argocd_web_url       = "http://localhost:8080 (after port-forward)"
  }
}