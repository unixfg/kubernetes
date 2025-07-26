variable "environment" {
  description = "Environment name (e.g., dev, stage, prod)"
  type        = string
}

variable "git_repo_url" {
  description = "Git repository URL for ArgoCD applications"
  type        = string
  default     = "https://github.com/unixfg/kubernetes-config.git"
}

variable "git_revision" {
  description = "Git revision/branch to track"
  type        = string
  default     = "HEAD"
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

variable "argocd_chart_version" {
  description = "ArgoCD Helm chart version"
  type        = string
  default     = null
}

variable "argocd_project" {
  description = "ArgoCD project for applications"
  type        = string
  default     = "default"
}

variable "argocd_values" {
  description = "ArgoCD Helm chart values"
  type        = any
  default = {
    server = {
      service = {
        type = "ClusterIP"
      }
      extraArgs = ["--insecure"]
    }
  }
}

variable "app_discovery_directories" {
  description = "List of directories to scan for applications"
  type        = list(object({
    path = string
  }))
  default = [
    {
      path = "apps/*"
    }
  ]
}

variable "sync_policy" {
  description = "ArgoCD sync policy configuration"
  type        = any
  default = {
    automated = {
      prune    = true
      selfHeal = true
    }
    syncOptions = [
      "CreateNamespace=true"
    ]
  }
}

variable "create_applicationset" {
  description = "Whether to create the ApplicationSet for automatic app discovery"
  type        = bool
  default     = true
}
