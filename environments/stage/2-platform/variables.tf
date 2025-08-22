# Stage 2-argocd Variables (GitOps/ArgoCD)

variable "environment" {
  description = "Environment name (e.g., test, prod)"
  type        = string
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
  description = "Name of the Kubernetes Secret to store ArgoCD repo SSH private key."
  type        = string
  default     = "argocd-repo-ssh"
}

variable "enable_applicationsets" {
  description = "Whether to enable ApplicationSets for automatic app discovery. Set to false for initial cluster deployment."
  type        = bool
  default     = false
}
