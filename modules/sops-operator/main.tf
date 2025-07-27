# SOPS Operator Module - Cloud-agnostic secret encryption for Kubernetes
# Supports multiple providers: Azure Key Vault, AWS KMS, GCP KMS, Age keys

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
    time = {
      source  = "hashicorp/time"
      version = "~>0.9"
    }
  }
}

# Get current Azure client configuration
data "azurerm_client_config" "current" {}

# Azure Key Vault for SOPS encryption (using RBAC)
resource "azurerm_key_vault" "sops" {
  name                = var.key_vault_name
  location            = var.location
  resource_group_name = var.resource_group_name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"

  soft_delete_retention_days = var.soft_delete_retention_days
  purge_protection_enabled   = var.purge_protection_enabled

  # Use RBAC authorization model (modern approach)
  enable_rbac_authorization = true

  tags = var.tags
}

# Grant current user Key Vault Administrator access
resource "azurerm_role_assignment" "current_user_admin" {
  scope                = azurerm_key_vault.sops.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = data.azurerm_client_config.current.object_id
}

# Add delay to ensure Key Vault and RBAC are fully ready
resource "time_sleep" "wait_for_key_vault" {
  create_duration = "30s"
  
  depends_on = [
    azurerm_key_vault.sops,
    azurerm_role_assignment.current_user_admin
  ]
}

# SOPS encryption key in Key Vault
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

  depends_on = [time_sleep.wait_for_key_vault]

  tags = var.tags
}

# Additional RBAC role assignments for Key Vault access
resource "azurerm_role_assignment" "additional" {
  for_each = var.rbac_assignments

  scope                = azurerm_key_vault.sops.id
  role_definition_name = each.value.role_definition_name
  principal_id         = each.value.principal_id
}

# Optional: Azure AD Application for Workload Identity
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

# Grant the workload identity service principal access to Key Vault
resource "azurerm_role_assignment" "workload_identity" {
  count = var.create_workload_identity ? 1 : 0

  scope                = azurerm_key_vault.sops.id
  role_definition_name = "Key Vault Crypto User"
  principal_id         = azuread_service_principal.workload_identity[0].object_id
}

# Federated identity credential for workload identity
resource "azuread_application_federated_identity_credential" "workload_identity" {
  count = var.create_workload_identity ? 1 : 0

  application_id   = azuread_application.workload_identity[0].id
  display_name     = var.workload_identity_name
  description      = var.workload_identity_description
  audiences        = ["api://AzureADTokenExchange"]
  issuer           = var.oidc_issuer_url
  subject          = var.workload_identity_subject
}

# Create a ConfigMap with workload identity configuration for GitOps consumption
resource "kubernetes_config_map" "sops_workload_identity" {
  count = var.create_workload_identity ? 1 : 0

  metadata {
    name      = "sops-workload-identity"
    namespace = "sops-secrets-operator-system"  # Same namespace as the operator
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      "app.kubernetes.io/component"  = "sops-operator"
      "environment"                  = var.environment
    }
  }

  data = {
    client_id = azuread_application.workload_identity[0].client_id
    tenant_id = data.azurerm_client_config.current.tenant_id
    # Add the Key Vault URL for SOPS encryption
    key_vault_url = local.azure_key_url
    key_vault_name = azurerm_key_vault.sops.name
    key_vault_uri = azurerm_key_vault.sops.vault_uri
  }

  depends_on = [
    azuread_application.workload_identity,
    azuread_service_principal.workload_identity
  ]
}

# Add the local for azure_key_url if not already present
locals {
  azure_key_url = "${azurerm_key_vault.sops.vault_uri}keys/${azurerm_key_vault_key.sops.name}/${azurerm_key_vault_key.sops.version}"
}
