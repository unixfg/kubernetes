# K3s SOPS Module Outputs
# GPG key outputs for SOPS configuration

# GPG configuration outputs
output "gpg_fingerprint" {
  description = "GPG key fingerprint for SOPS configuration"
  value       = local.gpg_fingerprint
}

output "gpg_secret_name" {
  description = "Name of the source GPG secret"
  value       = var.gpg_secret_name
}

output "gpg_secret_namespace" {
  description = "Namespace of the source GPG secret"
  value       = var.gpg_secret_namespace
}

# SOPS operator configuration outputs
output "sops_gpg_secret_name" {
  description = "Name of the GPG secret created for SOPS operator"
  value       = kubernetes_secret.sops_gpg_keys.metadata[0].name
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
      pgp = local.gpg_fingerprint
    }
  ])
}

# Configuration for GitOps integration
output "sops_configuration" {
  description = "Complete SOPS configuration for GitOps consumption"
  value = {
    gpg_fingerprint = local.gpg_fingerprint
    secret_name     = kubernetes_secret.sops_gpg_keys.metadata[0].name
    namespace       = var.sops_operator_namespace
    config_map      = kubernetes_config_map.sops_gpg_config.metadata[0].name
    creation_rules = [
      {
        pgp = local.gpg_fingerprint
      }
    ]
    instructions = <<-EOT
      To use SOPS with this GPG configuration:

      1. Encrypt secrets using:
         sops --encrypt --pgp ${local.gpg_fingerprint} secret.yaml > secret.enc.yaml

      2. Or create a .sops.yaml file with:
         creation_rules:
           - pgp: ${local.gpg_fingerprint}

      3. The SOPS operator will automatically decrypt secrets in the cluster
         using the GPG keys stored in secret: ${kubernetes_secret.sops_gpg_keys.metadata[0].name}
    EOT
  }
}