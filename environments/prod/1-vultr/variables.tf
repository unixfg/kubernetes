###############################################
# Variables for VKS Cluster Configuration (1-vultr)
###############################################

variable "kubeconfig_path" {
  description = "Path to kubeconfig file for VKS cluster"
  type        = string
  default     = "~/.kube/config"
}

variable "metrics_server_version" {
  description = "Version of metrics-server Helm chart to deploy"
  type        = string
  default     = "3.12.2"  # Latest stable as of 2024
}

variable "metrics_server_replicas" {
  description = "Number of metrics-server replicas for high availability"
  type        = number
  default     = 2

  validation {
    condition     = var.metrics_server_replicas >= 1 && var.metrics_server_replicas <= 5
    error_message = "Metrics server replicas must be between 1 and 5"
  }
}

variable "environment" {
  description = "Environment name (defaults to parent directory name if not specified)"
  type        = string
  default     = ""
}
