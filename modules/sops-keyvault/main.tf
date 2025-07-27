# SOPS Key Vault Module - Provides Azure Key Vault for SOPS encryption
# This module creates Key Vault resources for SOPS secret management

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~>2.0"
    }
  }
}

# Get current Azure client configuration
data "azurerm_client_config" "current" {}

# Azure Key Vault for SOPS encryption
resource "azurerm_key_vault" "sops" {
  name                = var.key_vault_name
  location            = var.location
  resource_group_name = var.resource_group_name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"

  soft_delete_retention_days = var.soft_delete_retention_days
  purge_protection_enabled   = var.purge_protection_enabled

  tags = var.tags
}

# SOPS encryption key
resource "azurerm_key_vault_key" "sops" {
  name         = var.key_name
  key_vault_id = azurerm_key_vault.sops.id
  key_type     = "RSA"
  key_size     = 2048

  key_opts = [
    "decrypt",
    "encrypt",
    "sign",
    "unwrapKey",
    "verify",
    "wrapKey",
  ]

  tags = var.tags
}

# Access policy for Terraform user
resource "azurerm_key_vault_access_policy" "terraform_user" {
  key_vault_id = azurerm_key_vault.sops.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azurerm_client_config.current.object_id

  key_permissions = [
    "Create", "Delete", "Get", "List", "Update",
    "Decrypt", "Encrypt", "Sign", "UnwrapKey", "Verify", "WrapKey",
  ]
}

# Dynamic access policies for additional principals
resource "azurerm_key_vault_access_policy" "additional" {
  for_each = var.access_policies

  key_vault_id = azurerm_key_vault.sops.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = each.value.object_id

  key_permissions = each.value.key_permissions

  depends_on = [azurerm_key_vault_access_policy.terraform_user]
}

# Optional: Workload Identity resources
resource "azuread_application" "workload_identity" {
  count = var.create_workload_identity ? 1 : 0
  
  display_name = var.workload_identity_name
  owners       = [data.azurerm_client_config.current.object_id]
}

resource "azuread_service_principal" "workload_identity" {
  count = var.create_workload_identity ? 1 : 0
  
  client_id = azuread_application.workload_identity[0].client_id
  owners    = [data.azurerm_client_config.current.object_id]
}

# Access policy for workload identity service principal
resource "azurerm_key_vault_access_policy" "workload_identity" {
  count = var.create_workload_identity ? 1 : 0
  
  key_vault_id = azurerm_key_vault.sops.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azuread_service_principal.workload_identity[0].object_id

  key_permissions = ["Decrypt", "Get"]

  depends_on = [azurerm_key_vault_access_policy.terraform_user]
}

# Federated identity credential
resource "azuread_application_federated_identity_credential" "workload_identity" {
  count = var.create_workload_identity ? 1 : 0
  
  application_object_id = azuread_application.workload_identity[0].object_id
  display_name         = var.workload_identity_name
  description          = var.workload_identity_description
  audiences            = ["api://AzureADTokenExchange"]
  issuer               = var.oidc_issuer_url
  subject              = var.workload_identity_subject
}
