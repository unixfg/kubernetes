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

output "cluster_credentials" {
  value = "az aks get-credentials --resource-group ${azurerm_resource_group.main.name} --name ${azurerm_kubernetes_cluster.main.name}"
  description = "Command to configure kubectl for this cluster"
}

output "cluster_info" {
  value = "kubectl cluster-info"
  description = "Get cluster endpoint information"
}
