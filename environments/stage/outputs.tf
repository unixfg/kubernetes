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
    
    🚀 Stage Environment Deployed Successfully!
    
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
      → ${replace(var.git_repo_url, ".git", "")}}/settings/keys
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
  value       = module.sops_keyvault.key_vault_name
  description = "Name of the Key Vault used for SOPS encryption"
}

output "sops_azure_kv_url" {
  value       = module.sops_keyvault.sops_azure_kv_url
  description = "Full Azure Key Vault URL for SOPS encryption"
}

# Workload Identity configuration for sops-secrets-operator
output "sops_operator_client_id" {
  value       = module.sops_keyvault.workload_identity_client_id
  description = "Client ID for the sops-secrets-operator workload identity"
}

output "sops_configuration" {
  description = "SOPS configuration instructions"
  value = <<-EOT
    
    📋 Next Steps for SOPS Configuration:
    
    1. Update ~/.sops.yaml or gitops/.sops.yaml:
    
    creation_rules:
      - path_regex: sops-secrets/.*\.yaml$
        azure_keyvault: "${module.sops_keyvault.sops_azure_kv_url}"
    
    2. Update gitops/apps/sops-secrets-operator/overlays/stage/kustomization.yaml:
    
    Add patches to configure workload identity:
    
    patchesStrategicMerge:
      - service-account-patch.yaml
      - deployment-patch.yaml
    
    Create service-account-patch.yaml:
    apiVersion: v1
    kind: ServiceAccount
    metadata:
      name: sops-secrets-operator-controller-manager
      namespace: sops-secrets-operator-system
      annotations:
        azure.workload.identity/client-id: "${module.sops_keyvault.workload_identity_client_id}"
      labels:
        azure.workload.identity/use: "true"
    
    Create deployment-patch.yaml:
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: sops-secrets-operator-controller-manager
      namespace: sops-secrets-operator-system
    spec:
      template:
        metadata:
          labels:
            azure.workload.identity/use: "true"
        spec:
          serviceAccountName: sops-secrets-operator-controller-manager
          containers:
          - name: manager
            env:
            - name: AZURE_CLIENT_ID
              value: "${module.sops_keyvault.workload_identity_client_id}"
            - name: AZURE_TENANT_ID
              value: "${data.azurerm_client_config.current.tenant_id}"
    
    3. Test encryption:
    sops -e --azure-kv "${module.sops_keyvault.sops_azure_kv_url}" --encrypted-suffix='Templates' test.yaml
    
    Key Vault: ${module.sops_keyvault.key_vault_name}
    Resource Group: ${module.aks.resource_group_name}
    Client ID: ${module.sops_keyvault.workload_identity_client_id}
    
  EOT
}
