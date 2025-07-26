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
  description = "Public SSH key for ArgoCD to access private config repo"
  value       = trimspace(module.argocd.argocd_repo_public_key)
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

# Essential next steps in a clean format
output "next_steps" {
  description = "Essential post-deployment steps"
  value = format("%s\n%s\n%s\n%s\n%s\n%s\n%s",
    "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━",
    "🚀 DEPLOYMENT COMPLETE! Infrastructure includes:",
    "   • AKS Cluster: ${module.aks.cluster_name} • ArgoCD: GitOps • MetalLB: LoadBalancer (10.240.0.100-10.240.0.150)",
    "",
    "1. Add SSH key to GitHub: ${trimspace(module.argocd.argocd_repo_public_key)}",
    "   → https://github.com/unixfg/gitops/settings/keys",
    "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  )
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
    check_metallb      = "kubectl get pods -n metallb-system"
    check_loadbalancers = "kubectl get svc --all-namespaces | grep LoadBalancer"  
    metallb_ip_pools   = "kubectl get ipaddresspools -n metallb-system"
  }
}

# MetalLB specific outputs
output "metallb_namespace" {
  description = "MetalLB namespace"
  value       = module.metallb.namespace
}

output "metallb_ip_pools" {
  description = "MetalLB IP address pools configured"
  value = [
    {
      name      = "${local.environment_name}-pool"
      addresses = "10.240.0.100-10.240.0.150"
    }
  ]
}
