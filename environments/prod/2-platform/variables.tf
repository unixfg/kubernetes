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

# K3s SOPS Configuration
variable "gpg_secret_name" {
  description = "Name of the Kubernetes secret containing GPG keys for SOPS"
  type        = string
  default     = "sops-gpg-keys"
}

variable "gpg_secret_namespace" {
  description = "Namespace of the Kubernetes secret containing GPG keys"
  type        = string
  default     = "default"
}

variable "gpg_fingerprint" {
  description = "GPG key fingerprint for SOPS configuration"
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