# ArgoCD Module Output Values
# Provides access to ArgoCD deployment details and connection information

output "argocd_namespace" {
  value       = kubernetes_namespace.argocd.metadata[0].name
  description = "ArgoCD namespace name"
}

output "argocd_repo_public_key" {
  description = "Public SSH key for ArgoCD to access private config repo. Add this as a deploy key."
  value       = tls_private_key.argocd_repo.public_key_openssh
}

output "argocd_port_forward_command" {
  value       = "kubectl port-forward svc/argocd-server -n ${kubernetes_namespace.argocd.metadata[0].name} 8080:80"
  description = "Command to access ArgoCD via HTTP port forwarding"
}

output "argocd_secret_name" {
  value       = kubernetes_secret.argocd_repo_ssh.metadata[0].name
  description = "Name of the ArgoCD repository SSH secret"
}
