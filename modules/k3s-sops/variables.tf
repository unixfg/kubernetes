# K3s SOPS Module Variables
# Age key configuration for secret encryption

variable "age_secret_name" {
  description = "Name of the Kubernetes secret containing Age key"
  type        = string
  default     = "sops-age"
}

variable "age_secret_namespace" {
  description = "Namespace of the Kubernetes secret containing Age key"
  type        = string
  default     = "sops-secrets-operator"
}

variable "age_key_field" {
  description = "Field name in the secret containing the Age private key"
  type        = string
  default     = "age.key"
}

variable "age_public_key" {
  description = "Age public key for SOPS configuration"
  type        = string
  default     = ""
}

variable "age_key_content" {
  description = "Age private key content. If provided, will use this instead of reading from cluster secret."
  type        = string
  default     = ""
  sensitive   = true
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
