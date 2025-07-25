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

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}
