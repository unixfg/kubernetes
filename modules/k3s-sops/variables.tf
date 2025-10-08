# K3s SOPS Module Variables
# GPG key configuration for secret encryption

variable "gpg_secret_name" {
  description = "Name of the Kubernetes secret containing GPG keys"
  type        = string
}

variable "gpg_secret_namespace" {
  description = "Namespace of the Kubernetes secret containing GPG keys"
  type        = string
}

variable "gpg_private_key_field" {
  description = "Field name in the secret containing the GPG private key"
  type        = string
  default     = "private.asc"
}

variable "gpg_public_key_field" {
  description = "Field name in the secret containing the GPG public key"
  type        = string
  default     = "public.asc"
}

variable "gpg_fingerprint" {
  description = "GPG key fingerprint for SOPS configuration. If empty, will attempt to extract from key"
  type        = string
  default     = ""
}

variable "gpg_private_key_content" {
  description = "GPG private key content (base64 encoded ASCII-armored). If provided, will use this instead of reading from cluster secret."
  type        = string
  default     = ""
  sensitive   = true
}

variable "gpg_public_key_content" {
  description = "GPG public key content (base64 encoded ASCII-armored). If provided, will use this instead of reading from cluster secret."
  type        = string
  default     = ""
}

variable "sops_operator_namespace" {
  description = "Namespace where SOPS secrets operator is deployed"
  type        = string
  default     = "sops-secrets-operator"
}

variable "environment" {
  description = "Environment name (e.g., dev, stage, prod)"
  type        = string
}

variable "create_sops_config" {
  description = "Create SOPS configuration file as ConfigMap"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Resource tags to apply to ConfigMaps and Secrets"
  type        = map(string)
  default     = {}
}