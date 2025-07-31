# Stage Environment Output Values  
# Provides access to deployed infrastructure details and connection information

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

# GitOps and Repository Access
output "argocd_repo_public_key" {
  description = "Public SSH key for ArgoCD to access private config repo"
  value       = trimspace(module.argocd.argocd_repo_public_key)
}

# Kubernetes Cluster Connection Details (sensitive)
output "kube_config_raw" {
  description = "Raw kubeconfig for the cluster"
  value       = module.aks.kube_config_raw
  sensitive   = true
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

# User-Friendly Deployment Summary
output "deployment_summary" {
  description = "Deployment summary"
  value = <<-EOT
    
    🚀 ${title(local.environment_name)} Environment Deployed Successfully!
    
    Cluster: ${module.aks.cluster_name}
    Region: ${var.resource_group_location}
    
    Connect to cluster:
      ${module.aks.cluster_credentials_command}
    
    Access ArgoCD:
      ${module.argocd.argocd_port_forward_command}
      Open: http://localhost:8080
      User: admin
      Pass: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
    
    Add deploy key to GitHub:
      ${trimspace(module.argocd.argocd_repo_public_key)}
      → ${replace(var.git_repo_url, ".git", "")}/settings/keys
  EOT
}

# Quick reference commands
output "commands" {
  description = "Quick command reference"
  value = <<-EOT
    
    kubectl get applications -n argocd    # Check deployed apps
    kubectl get pods --all-namespaces     # Check all pods
    kubectl get svc --all-namespaces      # Check all services
    terraform output -raw argocd_repo_public_key  # Get SSH key
  EOT
}

# Useful commands reference
output "useful_commands" {
  description = "Useful commands reference"
  value = {
    setup_kubectl       = module.aks.cluster_credentials_command
    access_argocd      = module.argocd.argocd_port_forward_command
    get_argocd_password = "kubectl -n ${module.argocd.argocd_namespace} get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
    check_applications = "kubectl get applications -n ${module.argocd.argocd_namespace}"
    view_ssh_key       = "terraform output -raw argocd_repo_public_key"
    argocd_web_url     = "http://localhost:8080 (after port-forward)"
  }
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
