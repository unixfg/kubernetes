# Stage 2-platform Outputs (GitOps Platform: ArgoCD + SOPS Operator)

# GitOps and Repository Access
output "argocd_repo_public_key" {
  description = "Public SSH key for ArgoCD to access private config repo"
  value       = trimspace(module.argocd.argocd_repo_public_key)
}

output "argocd_port_forward_command" {
  description = "Command to access ArgoCD via HTTP port forwarding"
  value       = module.argocd.argocd_port_forward_command
}

# SOPS Secrets Operator Status
output "sops_operator_status" {
  description = "SOPS Secrets Operator deployment status"
  value       = "SOPS Secrets Operator deployed in namespace '${helm_release.sops_secrets_operator.namespace}'"
}

output "sops_configmap_created" {
  description = "SOPS ConfigMap status for helper scripts"
  value       = "ConfigMap '${kubernetes_config_map.sops_workload_identity.metadata[0].name}' created with Key Vault URL"
}

# User-Friendly Deployment Summary
output "deployment_summary" {
  description = "Deployment summary"
  value = <<-EOT
    
    🚀 ${title(local.environment_name)} Environment GitOps Platform Ready!
    
    Cluster: ${data.terraform_remote_state.azure.outputs.cluster_name}
    Region: ${data.terraform_remote_state.azure.outputs.resource_group_location}
    
    Platform Components:
      ✅ ArgoCD (GitOps Controller) - namespace: ${module.argocd.argocd_namespace}
      ✅ SOPS Secrets Operator - namespace: ${helm_release.sops_secrets_operator.namespace}
      ✅ SOPS ConfigMap - Key Vault URL configured for helpers
    
    Connect to cluster:
      ${data.terraform_remote_state.azure.outputs.cluster_credentials_command}
    
    Access ArgoCD:
      ${module.argocd.argocd_port_forward_command}
      Open: http://localhost:8080
      User: admin
      Pass: kubectl -n argocd get secret argocd-initial-admin-secret -o go-template='{{printf "%s\n" (.data.password|base64decode)}}'
    
    Add deploy key to GitHub:
      ${trimspace(module.argocd.argocd_repo_public_key)}
      → ${replace(var.git_repo_url, ".git", "")}/settings/keys
      
    Next Steps:
      • Run 'sops-init' to configure SOPS encryption
      • Re-encrypt secrets with current Key Vault
      • Deploy applications via ArgoCD
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
    setup_kubectl        = data.terraform_remote_state.azure.outputs.cluster_credentials_command
    access_argocd        = module.argocd.argocd_port_forward_command
    get_argocd_password  = "kubectl -n argocd get secret argocd-initial-admin-secret -o go-template='{{printf \"%s\\n\" (.data.password|base64decode)}}'"
    check_applications   = "kubectl get applications -n ${module.argocd.argocd_namespace}"
    view_ssh_key         = "terraform output -raw argocd_repo_public_key"
    argocd_web_url       = "http://localhost:8080 (after port-forward)"
  }
}
