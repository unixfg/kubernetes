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

output "kube_config_raw" {
  description = "Raw kubeconfig for the cluster"
  value       = module.aks.kube_config_raw
  sensitive   = true
}

output "cluster_credentials" {
  value = module.aks.cluster_credentials_command
  description = "Command to configure kubectl for this cluster"
}

output "cluster_info" {
  value = "kubectl cluster-info"
  description = "Get cluster endpoint information"
}

# Cluster connection details for kubernetes-config terraform
output "cluster_host" {
  value = module.aks.cluster_host
  description = "Kubernetes cluster endpoint"
  sensitive = true
}

output "cluster_client_certificate" {
  value = module.aks.cluster_client_certificate
  description = "Kubernetes cluster client certificate"
  sensitive = true
}

output "cluster_client_key" {
  value = module.aks.cluster_client_key
  description = "Kubernetes cluster client key"
  sensitive = true
}

output "cluster_ca_certificate" {
  value = module.aks.cluster_ca_certificate
  description = "Kubernetes cluster CA certificate"
  sensitive = true
}
