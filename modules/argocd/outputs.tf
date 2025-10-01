# ArgoCD Module Output Values
# Provides access to ArgoCD deployment details and connection information

output "argocd_namespace" {
  value       = kubernetes_namespace.argocd.metadata[0].name
  description = "ArgoCD namespace name"
}

output "argocd_repo_public_key" {
  description = "Public SSH key for ArgoCD (only when using SSH auth)"
  value       = var.use_github_app ? "GitHub App authentication - no SSH key needed" : tls_private_key.argocd_repo[0].public_key_openssh
}

output "argocd_port_forward_command" {
  value       = "kubectl port-forward svc/argocd-server -n ${kubernetes_namespace.argocd.metadata[0].name} 8080:80"
  description = "Command to access ArgoCD via HTTP port forwarding"
}

output "argocd_secret_name" {
  value       = kubernetes_secret.argocd_repo_creds.metadata[0].name
  description = "Name of the ArgoCD repository credentials secret"
}

output "github_app_instructions" {
  description = "Instructions for GitHub App setup"
  value = var.use_github_app ? "GitHub App configured with ID: ${var.github_app_id}" : "Using SSH authentication"
}
