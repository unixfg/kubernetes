# SOPS Operator Module Outputs
# Azure Key Vault outputs for SOPS configuration

# Key Vault outputs
output "key_vault_id" {
  description = "ID of the Azure Key Vault"
  value       = azurerm_key_vault.sops.id
}

output "key_vault_name" {
  description = "Name of the Azure Key Vault"
  value       = azurerm_key_vault.sops.name
}

output "key_vault_uri" {
  description = "URI of the Azure Key Vault"
  value       = azurerm_key_vault.sops.vault_uri
}

output "key_id" {
  description = "ID of the SOPS encryption key"
  value       = azurerm_key_vault_key.sops.id
}

output "key_name" {
  description = "Name of the SOPS encryption key"
  value       = azurerm_key_vault_key.sops.name
}

output "key_version" {
  description = "Version of the SOPS encryption key"
  value       = azurerm_key_vault_key.sops.version
}

output "sops_azure_kv_url" {
  description = "Full Azure Key Vault URL for SOPS configuration"
  value       = "${azurerm_key_vault.sops.vault_uri}keys/${azurerm_key_vault_key.sops.name}/${azurerm_key_vault_key.sops.version}"
}

# Workload Identity outputs
output "workload_identity_client_id" {
  description = "Azure AD application client ID for workload identity"
  value       = var.create_workload_identity && length(azuread_application.workload_identity) > 0 ? azuread_application.workload_identity[0].client_id : ""
}

output "service_principal_object_id" {
  description = "Object ID of the service principal for workload identity"
  value       = var.create_workload_identity && length(azuread_service_principal.workload_identity) > 0 ? azuread_service_principal.workload_identity[0].object_id : ""
}

output "workload_identity_configuration" {
  description = "Configuration values for GitOps workload identity setup"
  value = var.create_workload_identity && length(azuread_application.workload_identity) > 0 ? {
    client_id    = azuread_application.workload_identity[0].client_id
    tenant_id    = data.azurerm_client_config.current.tenant_id
    instructions = <<-EOT
      To configure workload identity in your GitOps repository:
      
      1. Update service-account-patch.yaml with:
         azure.workload.identity/client-id: "${azuread_application.workload_identity[0].client_id}"
      
      2. Update deployment-patch.yaml with:
         AZURE_CLIENT_ID: "${azuread_application.workload_identity[0].client_id}"
         AZURE_TENANT_ID: "${data.azurerm_client_config.current.tenant_id}"
      
      3. Ensure both ServiceAccount and Pod have label:
         azure.workload.identity/use: "true"
    EOT
  } : null
}
