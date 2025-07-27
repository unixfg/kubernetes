# SOPS Operator Module Variables
# Azure Key Vault configuration for secret encryption

variable "key_vault_name" {
  description = "Name of the Azure Key Vault"
  type        = string
}

variable "location" {
  description = "Azure region for resources"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the Azure resource group"
  type        = string
}

variable "key_name" {
  description = "Name of the SOPS encryption key"
  type        = string
  default     = "sops-key"
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}

variable "environment" {
  description = "Environment name (e.g., dev, stage, prod)"
  type        = string
}

variable "soft_delete_retention_days" {
  description = "Soft delete retention in days"
  type        = number
  default     = 7
}

variable "purge_protection_enabled" {
  description = "Enable purge protection"
  type        = bool
  default     = false
}

variable "rbac_assignments" {
  description = "Additional RBAC role assignments for the Key Vault"
  type = map(object({
    principal_id         = string
    role_definition_name = string
  }))
  default = {}
}

# Workload Identity Configuration
variable "create_workload_identity" {
  description = "Create workload identity resources"
  type        = bool
  default     = false
}

variable "workload_identity_name" {
  description = "Name for workload identity"
  type        = string
  default     = ""
}

variable "workload_identity_description" {
  description = "Description for workload identity"
  type        = string
  default     = ""
}

variable "oidc_issuer_url" {
  description = "OIDC issuer URL from Kubernetes cluster"
  type        = string
  default     = ""
}

variable "workload_identity_subject" {
  description = "Subject for federated identity (Kubernetes service account)"
  type        = string
  default     = "system:serviceaccount:sops-secrets-operator-system:sops-secrets-operator"
}
