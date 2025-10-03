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

# Namespace for sops-secrets-operator
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

# SOPS Secrets Operator for K3s
#
# HYBRID BOOTSTRAP APPROACH:
# - Terraform: Ensures operator exists during cluster bootstrap (Stage 2)
# - ArgoCD: Manages day-2 operations, updates, and drift detection
#
# The lifecycle block below allows ArgoCD to take over management while
# Terraform maintains the initial bootstrap guarantee. This prevents conflicts
# between Terraform and ArgoCD when both are managing the same resource.
#
# To enable ArgoCD management, create an Application in the GitOps repo:
#   - Set syncPolicy.automated.selfHeal: true
#   - Use chart version with auto-update (e.g., "0.23.x")
#   - Reference the same namespace and values
resource "helm_release" "sops_secrets_operator" {
  name       = "sops-secrets-operator"
  repository = "https://isindir.github.io/sops-secrets-operator/"
  chart      = "sops-secrets-operator"
  version    = "0.23.0"
  namespace  = kubernetes_namespace.sops_secrets_operator.metadata[0].name

  values = [
    yamlencode({
      image = {
        tag = "0.17.0"
      }

      replicaCount = 1

      resources = {
        limits = {
          cpu    = "100m"
          memory = "128Mi"
        }
        requests = {
          cpu    = "50m"
          memory = "64Mi"
        }
      }

      env = {
        WATCH_NAMESPACE = ""  # Watch all namespaces
      }

      serviceAccount = {
        create = true
        name   = "sops-secrets-operator"
      }

      # Leader election is enabled by default in v0.17.0 (cannot be tuned via Helm)
      # Operator uses hardcoded leader election settings from controller-runtime

      # Logging configuration
      logging = {
        development     = false
        encoder         = "json"
        level           = "info"
        stacktraceLevel = "error"
        timeEncoding    = "iso8601"
      }

      # Mount GPG keys using secretsAsFiles for manual GPG setup
      secretsAsFiles = [
        {
          mountPath  = "/home/nonroot/.gnupg"
          name       = "sops-gpg-keys"
          secretName = "sops-gpg-keys"
        }
      ]
    })
  ]

  # Allow ArgoCD to manage updates without Terraform interference
  lifecycle {
    ignore_changes = [
      version,  # Let ArgoCD manage chart version updates
      values,   # Let ArgoCD manage Helm values changes
    ]
  }

  depends_on = [kubernetes_namespace.sops_secrets_operator]
}

# K3s SOPS Module - GPG-based secrets management
module "k3s_sops" {
  source = "../../../modules/k3s-sops"

  gpg_secret_name         = var.gpg_secret_name
  gpg_secret_namespace    = var.gpg_secret_namespace
  gpg_fingerprint         = var.gpg_fingerprint
  sops_operator_namespace = kubernetes_namespace.sops_secrets_operator.metadata[0].name
  environment             = local.environment_name

  create_sops_config = true

  depends_on = [helm_release.sops_secrets_operator]
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
}