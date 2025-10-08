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

output "gpg_fingerprint" {
  description = "GPG fingerprint used for SOPS encryption"
  value       = module.k3s_sops.gpg_fingerprint
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
      GPG Fingerprint: ${module.k3s_sops.gpg_fingerprint}
      Encrypt secrets: sops -e --pgp ${module.k3s_sops.gpg_fingerprint} secret.yaml > secret.enc.yaml

    Next Steps:
      • Create GPG keys if not already present in secret: ${var.gpg_secret_name}
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
    kubectl get secret ${var.gpg_secret_name} -n ${var.gpg_secret_namespace}  # Check GPG secret
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
    check_gpg_secret     = "kubectl get secret ${var.gpg_secret_name} -n ${var.gpg_secret_namespace}"
    sops_encrypt_command = "sops -e --pgp ${module.k3s_sops.gpg_fingerprint} secret.yaml > secret.enc.yaml"
    argocd_web_url       = "http://localhost:8080 (after port-forward)"
  }
}