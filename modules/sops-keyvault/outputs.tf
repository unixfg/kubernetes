# SOPS Key Vault Module Outputs
# Provides access to created resources for use in other modules

output "key_vault_id" {
  description = "ID of the Key Vault"
  value       = azurerm_key_vault.sops.id
}

output "key_vault_name" {
  description = "Name of the Key Vault"
  value       = azurerm_key_vault.sops.name
}

output "key_vault_uri" {
  description = "URI of the Key Vault"
  value       = azurerm_key_vault.sops.vault_uri
}

output "sops_key_id" {
  description = "ID of the SOPS key"
  value       = azurerm_key_vault_key.sops.id
}

output "sops_key_name" {
  description = "Name of the SOPS key"
  value       = azurerm_key_vault_key.sops.name
}

output "sops_key_version" {
  description = "Version of the SOPS key"
  value       = azurerm_key_vault_key.sops.version
}

output "sops_azure_kv_url" {
  description = "Full Azure Key Vault URL for SOPS configuration (.sops.yaml)"
  value       = "${azurerm_key_vault.sops.vault_uri}keys/${azurerm_key_vault_key.sops.name}/${azurerm_key_vault_key.sops.version}"
}

output "workload_identity_client_id" {
  description = "Client ID for workload identity (empty if not created)"
  value       = var.create_workload_identity ? azuread_application.workload_identity[0].client_id : ""
}

output "service_principal_object_id" {
  description = "Object ID of the service principal (empty if not created)"
  value       = var.create_workload_identity ? azuread_service_principal.workload_identity[0].object_id : ""
}
