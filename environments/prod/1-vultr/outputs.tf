###############################################
# Outputs for VKS Cluster Configuration (1-vultr)
###############################################

output "environment" {
  description = "Environment name"
  value       = local.environment_name
}

output "node_count" {
  description = "Number of nodes in the VKS cluster"
  value       = length(data.kubernetes_nodes.all.nodes)
}

output "kubernetes_version" {
  description = "Kubernetes version running on the cluster"
  value       = try(data.kubernetes_nodes.all.nodes[0].status[0].node_info[0].kubelet_version, "unknown")
}

output "metrics_server_installed" {
  description = "Whether metrics-server is installed"
  value       = helm_release.metrics_server.status == "deployed"
}

output "cluster_type" {
  description = "Type of Kubernetes cluster"
  value       = "vultr-vks"
}

output "next_steps" {
  description = "Instructions for proceeding to platform deployment"
  value = <<-EOT
    VKS cluster configuration complete!

    Next steps:
    1. cd ../2-platform
    2. Ensure Age key is set: export TF_VAR_age_key_content="$(cat ~/infrastructure/age.key)"
    3. Ensure GitHub App key is set: export TF_VAR_github_app_private_key="$(cat ~/infrastructure/github.key)"
    4. terraform init
    5. terraform plan -out main.tfplan
    6. terraform apply main.tfplan
  EOT
}

output "cluster_info_configmap" {
  description = "Name of ConfigMap containing cluster information"
  value       = kubernetes_config_map.vks_cluster_info.metadata[0].name
}
