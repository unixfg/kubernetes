# Stage 1-azure Variables (AKS + AKV/SOPS)

variable "environment" {
  description = "Environment name (e.g., dev, stage, prod)"
  type        = string
  default     = ""
}

variable "resource_group_location" {
  description = "Azure region for resources"
  type        = string
  default     = "northcentralus"
}

variable "node_count" {
  description = "Number of AKS nodes"
  type        = number
  default     = 3
}

variable "vm_size" {
  description = "VM size for AKS nodes"
  type        = string
  default     = "Standard_B2ms"
}

variable "random_pet_length" {
  description = "Length of random pet name for resource naming"
  type        = number
  default     = 2
}
