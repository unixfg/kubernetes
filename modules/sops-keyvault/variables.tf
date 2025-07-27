# SOPS Key Vault Module Variables
# Input variables for configuring the SOPS Key Vault module

variable "key_vault_name" {
  description = "Name of the Key Vault"
  type        = string
}

variable "location" {
  description = "Azure region for resources"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "key_name" {
  description = "Name of the SOPS encryption key"
  type        = string
  default     = "sops-key"
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

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}

variable "access_policies" {
  description = "Additional access policies for the Key Vault"
  type = map(object({
    object_id       = string
    key_permissions = list(string)
  }))
  default = {}
}

variable "create_workload_identity" {
  description = "Create workload identity resources for Kubernetes integration"
  type        = bool
  default     = false
}

variable "workload_identity_name" {
  description = "Name for workload identity application"
  type        = string
  default     = ""
}

variable "workload_identity_description" {
  description = "Description for workload identity"
  type        = string
  default     = ""
}

variable "oidc_issuer_url" {
  description = "OIDC issuer URL from AKS cluster"
  type        = string
  default     = ""
}

variable "workload_identity_subject" {
  description = "Subject for federated identity (Kubernetes service account)"
  type        = string
  default     = ""
}
