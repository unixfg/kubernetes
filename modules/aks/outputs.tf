# AKS Module Output Values
# Provides access to cluster details and connection information

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

# Cluster connection outputs - marked as sensitive for security
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

# Cluster managed identity outputs for Key Vault access
output "cluster_identity_principal_id" {
  value       = azurerm_kubernetes_cluster.main.identity.0.principal_id
  description = "Principal ID of the cluster's system-assigned managed identity"
}

output "cluster_identity_tenant_id" {
  value       = azurerm_kubernetes_cluster.main.identity.0.tenant_id
  description = "Tenant ID of the cluster's system-assigned managed identity"
}

# Workload Identity outputs
output "cluster_oidc_issuer_url" {
  value       = azurerm_kubernetes_cluster.main.oidc_issuer_url
  description = "OIDC issuer URL for workload identity federation"
}
