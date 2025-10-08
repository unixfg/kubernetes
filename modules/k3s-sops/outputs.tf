# K3s SOPS Module Outputs
# Age key outputs for SOPS configuration

# Age configuration outputs
output "age_public_key" {
  description = "Age public key for SOPS configuration"
  value       = local.age_public_key
}

output "age_secret_name" {
  description = "Name of the source Age secret"
  value       = var.age_secret_name
}

output "age_secret_namespace" {
  description = "Namespace of the source Age secret"
  value       = var.age_secret_namespace
}

# SOPS operator configuration outputs
output "sops_age_secret_name" {
  description = "Name of the Age secret created for SOPS operator"
  value       = kubernetes_secret.sops_age.metadata[0].name
}

output "sops_operator_namespace" {
  description = "Namespace where SOPS operator resources are created"
  value       = var.sops_operator_namespace
}

output "sops_config_name" {
  description = "Name of the SOPS configuration ConfigMap"
  value       = var.create_sops_config ? kubernetes_config_map.sops_config[0].metadata[0].name : ""
}

# SOPS creation rules for external consumption
output "sops_creation_rules" {
  description = "SOPS creation rules in JSON format"
  value = jsonencode([
    {
      age = local.age_public_key
    }
  ])
}

# Configuration for GitOps integration
output "sops_configuration" {
  description = "Complete SOPS configuration for GitOps consumption"
  value = {
    age_public_key = local.age_public_key
    secret_name    = kubernetes_secret.sops_age.metadata[0].name
    namespace      = var.sops_operator_namespace
    config_map     = kubernetes_config_map.sops_age_config.metadata[0].name
    creation_rules = [
      {
        age = local.age_public_key
      }
    ]
    instructions = <<-EOT
      To use SOPS with this Age configuration:

      1. Encrypt secrets using:
         sops --encrypt --age ${local.age_public_key} secret.yaml > secret.enc.yaml

      2. Or create a .sops.yaml file with:
         creation_rules:
           - age: ${local.age_public_key}

      3. The SOPS operator will automatically decrypt secrets in the cluster
         using the Age key stored in secret: ${kubernetes_secret.sops_age.metadata[0].name}
    EOT
  }
}
