# ArgoCD Module - GitOps deployment and management
# This module deploys ArgoCD with automatic application discovery via ApplicationSet

# Create dedicated namespace for ArgoCD
resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"
  }
}

# Generate SSH key pair for ArgoCD repository access
resource "tls_private_key" "argocd_repo" {
  algorithm = "ED25519"
}

# Store SSH private key in Kubernetes Secret for ArgoCD repository access
resource "kubernetes_secret" "argocd_repo_ssh" {
  metadata {
    name      = var.argocd_repo_ssh_secret_name
    namespace = kubernetes_namespace.argocd.metadata[0].name
    labels = {
      "argocd.argoproj.io/secret-type" = "repository"
    }
  }

  data = {
    "sshPrivateKey" = tls_private_key.argocd_repo.private_key_openssh
    "url"           = var.use_ssh_for_git ? replace(var.git_repo_url, "https://github.com/", "git@github.com:") : var.git_repo_url
    "type"          = "git"
  }
}

# Install ArgoCD via Helm chart
resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  namespace  = kubernetes_namespace.argocd.metadata[0].name
  version    = var.argocd_chart_version

  values = [
    yamlencode(var.argocd_values)
  ]
}

# Create ConfigMap with environment configuration for applications
resource "kubernetes_config_map" "environment_config" {
  metadata {
    name      = "environment-config"
    namespace = kubernetes_namespace.argocd.metadata[0].name
  }

  data = {
    environment = var.environment
  }
}

# Wait for ArgoCD components to be fully ready before creating ApplicationSet
resource "time_sleep" "wait_for_argocd" {
  depends_on = [helm_release.argocd]
  create_duration = "30s"
}

# Local variable for field_manager block to ensure consistency
locals {
  argocd_field_manager = {
    name            = "terraform"
    force_conflicts = true
  }
}

# ArgoCD ApplicationSet for automatic Kustomize application discovery and deployment
resource "kubernetes_manifest" "app_discovery" {
  count      = var.create_applicationset ? 1 : 0
  depends_on = [time_sleep.wait_for_argocd, kubernetes_secret.argocd_repo_ssh]

  field_manager {
    name            = "terraform"
    force_conflicts = true
  }

  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "ApplicationSet"
    metadata = {
      name      = "kustomize-app-discovery"
      namespace = kubernetes_namespace.argocd.metadata[0].name
    }
    spec = {
      goTemplate = true
      generators = [
        {
          git = {
            repoURL  = var.use_ssh_for_git ? replace(var.git_repo_url, "https://github.com/", "git@github.com:") : var.git_repo_url
            revision = var.git_revision
            directories = [
              # Match with or without optional leading 'gitops/' by using two patterns
              { path = "apps/*/overlays/${var.environment}" },
              { path = "gitops/apps/*/overlays/${var.environment}" }
            ]
          }
        }
      ]
      template = {
        metadata = {
          # Derive app name: apps/<app>/overlays/<env>
          name = "{{ (index (splitList \"/\" .path.path) 1) }}-${var.environment}"
        }
        spec = {
          project = var.argocd_project
          source = {
            repoURL        = var.use_ssh_for_git ? replace(var.git_repo_url, "https://github.com/", "git@github.com:") : var.git_repo_url
            targetRevision = var.git_revision
            path           = "{{ .path.path }}"
          }
          destination = {
            server    = "https://kubernetes.default.svc"
            namespace = "{{ (index (splitList \"/\" .path.path) 1) }}"
          }
          ignoreDifferences = [
            {
              group = "isindir.github.com"
              kind  = "SopsSecret"
              jqPathExpressions = [
                ".spec.secretTemplates[].namespace"
              ]
            }
          ]
          syncPolicy = var.sync_policy
        }
      }
    }
  }
}

# ArgoCD ApplicationSet for Helm applications stored as Application manifests
# This discovers Application manifests and creates ArgoCD Applications from their contents.
resource "kubernetes_manifest" "helm_app_discovery" {
  count      = var.create_applicationset ? 1 : 0
  depends_on = [time_sleep.wait_for_argocd, kubernetes_secret.argocd_repo_ssh]

  field_manager {
    name            = "terraform"
    force_conflicts = true
  }

  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "ApplicationSet"
    metadata = {
      name      = "helm-app-discovery"
      namespace = kubernetes_namespace.argocd.metadata[0].name
    }
    spec = {
      goTemplate = true
      generators = [
        {
          git = {
            repoURL  = var.use_ssh_for_git ? replace(var.git_repo_url, "https://github.com/", "git@github.com:") : var.git_repo_url
            revision = var.git_revision
            files = [
              { path = "apps/*/helm/${var.environment}/application.yaml" },
              { path = "gitops/apps/*/helm/${var.environment}/application.yaml" }
            ]
          }
        }
      ]
      template = {
        metadata = {
          # Derive app name: apps/<app>/helm/<env>
          name = "{{ (index (splitList \"/\" .path.path) 1) }}-${var.environment}"
        }
        spec = {
          project = var.argocd_project

          # Support both styles: single-source (spec.source) or multi-source (spec.sources[0]).
          source = {
            repoURL        = "{{ if hasKey .spec \"source\" }}{{ .spec.source.repoURL }}{{ else }}{{ (index .spec.sources 0).repoURL }}{{ end }}"
            chart          = "{{ if hasKey .spec \"source\" }}{{ .spec.source.chart }}{{ else }}{{ (index .spec.sources 0).chart }}{{ end }}"
            targetRevision = "{{ if hasKey .spec \"source\" }}{{ .spec.source.targetRevision }}{{ else }}{{ (index .spec.sources 0).targetRevision }}{{ end }}"
            helm = {
              values = "{{ if hasKey .spec \"source\" }}{{ .spec.source.helm.values }}{{ else }}{{ (index .spec.sources 0).helm.values }}{{ end }}"
            }
          }

          destination = {
            server    = "https://kubernetes.default.svc"
            namespace = "{{ if hasKey .spec \"destination\" }}{{ .spec.destination.namespace }}{{ else }}{{ .metadata.name }}{{ end }}"
          }
          ignoreDifferences = [
            {
              group = "isindir.github.com"
              kind  = "SopsSecret"
              jqPathExpressions = [
                ".spec.secretTemplates[].namespace"
              ]
            }
          ]
          syncPolicy = var.sync_policy
        }
      }
    }
  }
}
