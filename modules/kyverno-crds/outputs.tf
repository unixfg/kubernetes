###############################################
# Kyverno CRDs Module Outputs
###############################################

output "kyverno_version" {
  description = "Kyverno version installed"
  value       = var.kyverno_version
}

output "crds_installed" {
  description = "List of Kyverno CRDs installed by this module"
  value = [
    kubectl_manifest.clusterpolicies.name,
    kubectl_manifest.policies.name,
  ]
}

output "installation_complete" {
  description = "Indicates CRD installation is complete"
  value       = true
  depends_on = [
    kubectl_manifest.clusterpolicies,
    kubectl_manifest.policies,
  ]
}
