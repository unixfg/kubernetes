output "cluster_name" {
  value = module.aks.cluster_name
  description = "Generated AKS cluster name"
}

output "resource_group_name" {
  value = module.aks.resource_group_name
  description = "Generated resource group name"
}

output "random_suffix" {
  value = module.aks.random_suffix
  description = "Random pet suffix used for naming"
}

output "argocd_port_forward_command" {
  value = module.argocd.argocd_port_forward_command
  description = "Command to access ArgoCD via HTTP port forwarding"
}

output "argocd_repo_public_key" {
  description = "Public SSH key for ArgoCD to access private config repo. Add this as a deploy key."
  value       = module.argocd.argocd_repo_public_key
}

output "cluster_credentials" {
  value = module.aks.cluster_credentials_command
  description = "Command to configure kubectl for this cluster"
}

output "cluster_info" {
  value = "kubectl cluster-info"
  description = "Get cluster endpoint information"
}
