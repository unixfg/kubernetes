# Prod 2-platform Variables (GitOps/ArgoCD for K3s)

variable "environment" {
  description = "Environment name (e.g., prod, dev)"
  type        = string
  default     = "prod"
}

variable "git_repo_url" {
  description = "Git repository URL for ArgoCD applications"
  type        = string
  default     = "https://github.com/unixfg/gitops.git"
}

variable "use_ssh_for_git" {
  description = "Whether to use SSH for git repository access (required for private repos)"
  type        = bool
  default     = true
}

variable "argocd_repo_ssh_secret_name" {
  description = "Name of the Kubernetes Secret to store ArgoCD repo SSH private key"
  type        = string
  default     = "argocd-repo-ssh"
}

variable "enable_applicationsets" {
  description = "Whether to enable ApplicationSets for automatic app discovery. Set to false for initial cluster deployment."
  type        = bool
  default     = false
}

# K3s SOPS Configuration - Age encryption
variable "age_public_key" {
  description = "Age public key for SOPS configuration"
  type        = string
}

variable "argocd_domain" {
  description = "Domain name for ArgoCD ingress"
  type        = string
  default     = "argocd.example.com"
}

variable "ingress_enabled" {
  description = "Whether to enable ArgoCD ingress"
  type        = bool
  default     = false
}

# GitHub App Configuration
variable "use_github_app" {
  description = "Whether to use GitHub App for authentication instead of SSH"
  type        = bool
  default     = false
}

variable "github_app_id" {
  description = "GitHub App ID for ArgoCD authentication"
  type        = string
  default     = ""
}

variable "github_app_installation_id" {
  description = "GitHub App Installation ID"
  type        = string
  default     = ""
}

variable "github_app_private_key" {
  description = "GitHub App private key (PEM format)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "argocd_repo_secret_name" {
  description = "Name of the Kubernetes Secret to store ArgoCD repo credentials"
  type        = string
  default     = "argocd-repo-creds"
}

# Webhook Configuration
variable "enable_webhooks" {
  description = "Whether to enable GitHub webhooks for immediate sync instead of polling"
  type        = bool
  default     = false
}

variable "github_webhook_secret" {
  description = "Secret for GitHub webhook validation (base64 encoded)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "webhook_max_payload_size_mb" {
  description = "Maximum webhook payload size in MB to prevent DDoS attacks"
  type        = string
  default     = "10"
}

variable "age_key_content" {
  description = "Age private key content. Provide via TF_VAR_age_key_content env var for security."
  type        = string
  default     = ""
  sensitive   = true
}