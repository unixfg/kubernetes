# ArgoCD Module

This module installs and configures ArgoCD for GitOps deployment and management on a Kubernetes cluster.

## Features

- **ArgoCD Installation**: Installs ArgoCD via Helm chart
- **SSH Key Management**: Generates and manages SSH keys for private repository access
- **Environment Configuration**: Creates environment-specific ConfigMaps
- **ApplicationSet**: Automatically discovers and deploys applications from Git repositories
- **Flexible Configuration**: Supports customizable ArgoCD values and sync policies

## Usage

```hcl
module "argocd" {
  source = "../../modules/argocd"
  
  environment                  = "dev"
  git_repo_url                = "https://github.com/unixfg/kubernetes-config.git"
  use_ssh_for_git             = true
  argocd_repo_ssh_secret_name = "argocd-repo-ssh"
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| environment | Environment name (e.g., dev, stage, prod) | `string` | n/a | yes |
| git_repo_url | Git repository URL for ArgoCD applications | `string` | `"https://github.com/unixfg/kubernetes-config.git"` | no |
| git_revision | Git revision/branch to track | `string` | `"HEAD"` | no |
| use_ssh_for_git | Whether to use SSH for git repository access | `bool` | `true` | no |
| argocd_repo_ssh_secret_name | Name of the Kubernetes Secret to store ArgoCD repo SSH private key | `string` | `"argocd-repo-ssh"` | no |
| argocd_chart_version | ArgoCD Helm chart version | `string` | `null` | no |
| argocd_project | ArgoCD project for applications | `string` | `"default"` | no |
| argocd_values | ArgoCD Helm chart values | `any` | See variables.tf | no |
| app_discovery_directories | List of directories to scan for applications | `list(object)` | `[{ path = "apps/*" }]` | no |
| sync_policy | ArgoCD sync policy configuration | `any` | See variables.tf | no |

## Outputs

| Name | Description |
|------|-------------|
| argocd_namespace | ArgoCD namespace name |
| argocd_repo_public_key | Public SSH key for ArgoCD to access private config repo |
| argocd_port_forward_command | Command to access ArgoCD via HTTP port forwarding |
| argocd_secret_name | Name of the ArgoCD repository SSH secret |

## Requirements

- Terraform >= 1.0
- kubernetes provider ~> 2.0
- helm provider ~> 2.0
- tls provider ~> 4.0

## Notes

- The module automatically generates SSH keys for repository access
- If using private repositories, add the generated public key as a deploy key
- The ApplicationSet automatically discovers applications in the specified directories
- Applications are expected to follow the `overlays/{environment}` structure
