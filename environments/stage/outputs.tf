output "cluster_name" {
  value = azurerm_kubernetes_cluster.main.name
  description = "Generated AKS cluster name"
}

output "resource_group_name" {
  value = azurerm_resource_group.main.name
  description = "Generated resource group name"
}

output "random_suffix" {
  value = random_pet.cluster.id
  description = "Random pet suffix used for naming"
}

output "argocd_port_forward_command" {
  value = "kubectl port-forward svc/argocd-server -n argocd 8080:80"
  description = "Command to access ArgoCD via HTTP port forwarding"
}

output "argocd_repo_public_key" {
  description = "Public SSH key for ArgoCD to access private config repo. Add this as a deploy key."
  value       = tls_private_key.argocd_repo.public_key_openssh
}

output "kube_config_raw" {
  description = "Raw kubeconfig for the cluster"
  value       = azurerm_kubernetes_cluster.main.kube_config_raw
  sensitive   = true
}

output "cluster_credentials" {
  value = "az aks get-credentials --resource-group ${azurerm_resource_group.main.name} --name ${azurerm_kubernetes_cluster.main.name}"
  description = "Command to configure kubectl for this cluster"
}

output "cluster_info" {
  value = "kubectl cluster-info"
  description = "Get cluster endpoint information"
}

# Cluster connection details for kubernetes-config terraform
output "cluster_host" {
  value = azurerm_kubernetes_cluster.main.kube_config.0.host
  description = "Kubernetes cluster endpoint"
  sensitive = true
}

output "cluster_client_certificate" {
  value = azurerm_kubernetes_cluster.main.kube_config.0.client_certificate
  description = "Kubernetes cluster client certificate"
  sensitive = true
}

output "cluster_client_key" {
  value = azurerm_kubernetes_cluster.main.kube_config.0.client_key
  description = "Kubernetes cluster client key"
  sensitive = true
}

output "cluster_ca_certificate" {
  value = azurerm_kubernetes_cluster.main.kube_config.0.cluster_ca_certificate
  description = "Kubernetes cluster CA certificate"
  sensitive = true
}
