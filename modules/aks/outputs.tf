output "cluster_name" {
  value       = azurerm_kubernetes_cluster.main.name
  description = "Generated AKS cluster name"
}

output "resource_group_name" {
  value       = azurerm_resource_group.main.name
  description = "Generated resource group name"
}

output "resource_group_location" {
  value       = azurerm_resource_group.main.location
  description = "Resource group location"
}

output "random_suffix" {
  value       = random_pet.cluster.id
  description = "Random pet suffix used for naming"
}

output "cluster_host" {
  value       = azurerm_kubernetes_cluster.main.kube_config.0.host
  description = "Kubernetes cluster endpoint"
  sensitive   = true
}

output "cluster_client_certificate" {
  value       = azurerm_kubernetes_cluster.main.kube_config.0.client_certificate
  description = "Kubernetes cluster client certificate"
  sensitive   = true
}

output "cluster_client_key" {
  value       = azurerm_kubernetes_cluster.main.kube_config.0.client_key
  description = "Kubernetes cluster client key"
  sensitive   = true
}

output "cluster_ca_certificate" {
  value       = azurerm_kubernetes_cluster.main.kube_config.0.cluster_ca_certificate
  description = "Kubernetes cluster CA certificate"
  sensitive   = true
}

output "kube_config_raw" {
  description = "Raw kubeconfig for the cluster"
  value       = azurerm_kubernetes_cluster.main.kube_config_raw
  sensitive   = true
}

output "cluster_credentials_command" {
  value       = "az aks get-credentials --resource-group ${azurerm_resource_group.main.name} --name ${azurerm_kubernetes_cluster.main.name}"
  description = "Command to configure kubectl for this cluster"
}
