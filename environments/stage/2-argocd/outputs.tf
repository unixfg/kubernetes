# Stage 2-argocd Outputs (GitOps/ArgoCD)

# GitOps and Repository Access
output "argocd_repo_public_key" {
  description = "Public SSH key for ArgoCD to access private config repo"
  value       = trimspace(module.argocd.argocd_repo_public_key)
}

output "argocd_port_forward_command" {
  description = "Command to access ArgoCD via HTTP port forwarding"
  value       = module.argocd.argocd_port_forward_command
}

# User-Friendly Deployment Summary
output "deployment_summary" {
  description = "Deployment summary"
  value = <<-EOT
    
    🚀 ${title(local.environment_name)} Environment GitOps Ready!
    
    Cluster: ${data.terraform_remote_state.azure.outputs.cluster_name}
    Region: ${data.terraform_remote_state.azure.outputs.resource_group_location}
    
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
