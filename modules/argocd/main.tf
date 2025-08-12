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
          # App dir is 3rd from end (…/<app>/overlays/<env>)
          name = "{{ $s := split \"/\" .path }}{{ index $s (sub (len $s) 3) }}-${var.environment}"
        }
        spec = {
        spec = {
          project = var.argocd_project
          source = {
            repoURL        = var.use_ssh_for_git ? replace(var.git_repo_url, "https://github.com/", "git@github.com:") : var.git_repo_url
            targetRevision = var.git_revision
            path           = "{{ .path }}"
          }
          destination = {
            server    = "https://kubernetes.default.svc"
            namespace = "{{ $s := split \"/\" .path }}{{ index $s (sub (len $s) 3) }}"
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
          # Extract app name: directory is 4th from end (…/<app>/helm/<env>/application.yaml)
          name = "{{ $s := split \"/\" .path }}{{ index $s (sub (len $s) 4) }}-${var.environment}"
        }
        spec = {
          spec = {
            project = var.argocd_project
            # The following uses Go template expressions to extract values from .spec.sources array in the discovered Application manifest.
            # This is necessary because ApplicationSet templates do not natively merge nested fields; see ArgoCD docs for details.
            # Example: "{{ (index .spec.sources 0).repoURL }}" extracts the repoURL from the first source in the sources array.
            sources = [
              {
                repoURL        = "{{ (index .spec.sources 0).repoURL }}"
                chart          = "{{ (index .spec.sources 0).chart }}"
                targetRevision = "{{ (index .spec.sources 0).targetRevision }}"
                helm = {
                  values = "{{ (index .spec.sources 0).helm.values }}"
                }
              },
              {
                repoURL        = "{{ (index .spec.sources 1).repoURL }}"
                path           = "{{ (index .spec.sources 1).path }}"
                targetRevision = "{{ (index .spec.sources 1).targetRevision }}"
              }
            ]
            destination = {
              server    = "https://kubernetes.default.svc"
              namespace = "{{ .spec.destination.namespace }}"
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
  # Note: The double 'spec' block is intentional for consistency with the 'app_discovery' manifest structure.
}
