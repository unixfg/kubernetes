# Stage 1-azure Outputs (for consumption by 2-argocd)

output "cluster_name" {
  value       = module.aks.cluster_name
  description = "Generated AKS cluster name"
}

output "resource_group_name" {
  value       = module.aks.resource_group_name
  description = "Generated resource group name"
}

output "resource_group_location" {
  value       = var.resource_group_location
  description = "Azure region for deployment"
}

output "random_suffix" {
  value       = module.aks.random_suffix
  description = "Random pet suffix used for naming"
}

# Kubernetes Cluster Connection Details (sensitive)
output "kube_config_raw" {
  description = "Raw kubeconfig for the cluster"
  value       = module.aks.kube_config_raw
  sensitive   = true
}

output "cluster_credentials_command" {
  description = "Convenience command to set up kubectl context"
  value       = module.aks.cluster_credentials_command
}

# Cluster connection details for consumers
output "cluster_host" {
  value       = module.aks.cluster_host
  description = "Kubernetes cluster endpoint"
  sensitive   = true
}

output "cluster_client_certificate" {
  value       = module.aks.cluster_client_certificate
  description = "Kubernetes cluster client certificate"
  sensitive   = true
}

output "cluster_client_key" {
  value       = module.aks.cluster_client_key
  description = "Kubernetes cluster client key"
  sensitive   = true
}

output "cluster_ca_certificate" {
  value       = module.aks.cluster_ca_certificate
  description = "Kubernetes cluster CA certificate"
  sensitive   = true
}

# SOPS Configuration Outputs
output "sops_key_vault_name" {
  value       = module.akv_sops.key_vault_name
  description = "Name of the Key Vault used for SOPS encryption"
}

output "sops_azure_kv_url" {
  value       = module.akv_sops.sops_azure_kv_url
  description = "Full Azure Key Vault URL for SOPS encryption"
}

# Workload Identity configuration for sops-secrets-operator
output "akv_sops_client_id" {
  value       = module.akv_sops.workload_identity_client_id
  description = "Client ID for the sops-secrets-operator workload identity"
}

# Environment-specific outputs
output "environment" {
  value       = local.environment_name
  description = "Current environment name"
}
