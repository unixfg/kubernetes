# Stage Environment Input Variables
# Defines configurable parameters for the staging environment deployment

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

variable "environment" {
  description = "Environment name (e.g., test, prod)"
  type        = string
}

variable "git_repo_url" {
  description = "Git repository URL for ArgoCD applications"
  type        = string
  default     = "https://github.com/unixfg/kubernetes-config.git"
}

variable "use_ssh_for_git" {
  description = "Whether to use SSH for git repository access (required for private repos)"
  type        = bool
  default     = true
}

variable "argocd_repo_ssh_secret_name" {
  description = "Name of the Kubernetes Secret to store ArgoCD repo SSH private key."
  type        = string
  default     = "argocd-repo-ssh"
}
