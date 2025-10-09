###############################################
# Kyverno CRDs Module Variables
###############################################

variable "kyverno_version" {
  description = "Kyverno version tag to install CRDs from (e.g., v1.15.2)"
  type        = string
  default     = "v1.15.2"

  validation {
    condition     = can(regex("^v[0-9]+\\.[0-9]+\\.[0-9]+$", var.kyverno_version))
    error_message = "Kyverno version must be in format vX.Y.Z (e.g., v1.15.2)"
  }
}
