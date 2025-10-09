###############################################
# Prod Environment - 2-platform (GitOps Platform: ArgoCD + SOPS Operator for K3s)
###############################################

terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~>2.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~>2.0"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.14"
    }
  }
}

# Use parent directory name (e.g., "prod") as environment name
locals {
  environment_name = basename(dirname(path.cwd))
}

# Configure providers for k3s cluster
# Note: Configure kubectl context or use kube config file before running terraform
provider "kubernetes" {
  config_path = "~/.kube/config"
}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}

provider "kubectl" {
  config_path = "~/.kube/config"
}

# Namespace for sops-secrets-operator
# Note: ArgoCD manages the SOPS operator deployment, Terraform only ensures namespace exists
resource "kubernetes_namespace" "sops_secrets_operator" {
  metadata {
    name = "sops-secrets-operator"
    labels = {
      "name"                         = "sops-secrets-operator"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

# SOPS Secrets Operator is now fully managed by ArgoCD
# See gitops/apps/sops-secrets-operator/helm/prod/application.yaml for configuration
#
# This provides:
# - Consistent GitOps workflow for all components
# - Easy updates via git commits
# - Self-healing and drift detection
# - Proper GPG key mounting and import via custom values

# K3s SOPS Module - Age-based secrets management
# Note: Secret must be created BEFORE helm release to avoid mount failures
module "k3s_sops" {
  source = "../../../modules/k3s-sops"

  age_public_key          = var.age_public_key
  age_key_content         = var.age_key_content
  sops_operator_namespace = kubernetes_namespace.sops_secrets_operator.metadata[0].name
  environment             = local.environment_name

  create_sops_config = true

  depends_on = [kubernetes_namespace.sops_secrets_operator]
}

# Kyverno CRDs Bootstrap
# Install large CRDs that cause ArgoCD annotation size issues
# After bootstrap, ArgoCD manages updates via kyverno-crds application
module "kyverno_crds_bootstrap" {
  source = "../../../modules/kyverno-crds"

  kyverno_version = "v1.15.2"

  # Hand off management to ArgoCD after initial bootstrap
  lifecycle {
    ignore_changes = all
  }

  depends_on = [kubernetes_namespace.sops_secrets_operator]
}

# ArgoCD GitOps Controller
module "argocd" {
  source = "../../../modules/argocd"

  environment                 = var.environment
  git_repo_url                = var.git_repo_url
  use_ssh_for_git             = var.use_ssh_for_git
  use_github_app              = var.use_github_app
  github_app_id               = var.github_app_id
  github_app_installation_id  = var.github_app_installation_id
  github_app_private_key      = var.github_app_private_key
  argocd_repo_secret_name     = var.argocd_repo_secret_name
  create_applicationset       = var.enable_applicationsets

  # Webhook configuration
  enable_webhooks              = var.enable_webhooks
  github_webhook_secret        = var.github_webhook_secret
  webhook_max_payload_size_mb  = var.webhook_max_payload_size_mb

  argocd_values = merge({
    global = {
      domain = var.argocd_domain
    }
    repoServer = {
      env = [
        {
          name  = "NO_PROXY"
          value = "github.com,*.github.com,githubusercontent.com,*.githubusercontent.com"
        },
        {
          name  = "no_proxy"
          value = "github.com,*.github.com,githubusercontent.com,*.githubusercontent.com"
        }
      ]
    }
    server = {
      service = {
        type = "ClusterIP"
      }
      extraArgs = ["--insecure"]
    }
  }, var.ingress_enabled ? {
    server = {
      service = {
        type = "ClusterIP"
        servicePortHttp = 80
        servicePortHttps = 443
      }
      # Keep insecure for now, but serve on HTTPS port
      extraArgs = ["--insecure"]
      ingress = {
        enabled = true
        ingressClassName = "traefik"
        annotations = {
          "traefik.ingress.kubernetes.io/router.entrypoints" = "websecure"
          # Terminate TLS at ingress level instead of passthrough for now
          "traefik.ingress.kubernetes.io/router.tls" = "true"
        }
        hosts = [var.argocd_domain]
        tls = [{
          hosts = [var.argocd_domain]
          # Use default Traefik certificate for now
        }]
        # Route to HTTP port but serve via HTTPS ingress
        paths = [{
          path = "/"
          pathType = "Prefix"
          backend = {
            service = {
              name = "argocd-server"
              port = {
                number = 80
              }
            }
          }
        }]
      }
    }
  } : {})

  # Ensure Kyverno CRDs are installed before ArgoCD starts
  # This prevents ArgoCD from encountering missing CRDs during initial sync
  depends_on = [module.kyverno_crds_bootstrap]
}