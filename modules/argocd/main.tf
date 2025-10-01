# ArgoCD Module - GitOps deployment and management
# This module deploys ArgoCD with automatic application discovery via ApplicationSet

# Create dedicated namespace for ArgoCD
resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"
  }
}

# Generate SSH key pair for ArgoCD repository access (only when not using GitHub App)
resource "tls_private_key" "argocd_repo" {
  count     = var.use_github_app ? 0 : 1
  algorithm = "ED25519"
}

# Repository credentials secret (supports both SSH and GitHub App authentication)
resource "kubernetes_secret" "argocd_repo_creds" {
  metadata {
    name      = var.argocd_repo_secret_name
    namespace = kubernetes_namespace.argocd.metadata[0].name
    labels = {
      "argocd.argoproj.io/secret-type" = "repository"
    }
  }

  data = var.use_github_app ? {
    "type"                    = "git"
    "url"                     = var.git_repo_url
    "githubAppID"            = var.github_app_id
    "githubAppInstallationID" = var.github_app_installation_id
    "githubAppPrivateKey"    = var.github_app_private_key
  } : {
    "sshPrivateKey" = tls_private_key.argocd_repo[0].private_key_openssh
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
    yamlencode(merge(var.argocd_values, {
      repoServer = {
        volumes = [
          {
            name = "repo-credentials"
            secret = {
              secretName = var.argocd_repo_secret_name
            }
          }
        ]
        volumeMounts = [
          {
            name      = "repo-credentials"
            mountPath = "/app/config/repository"
            readOnly  = true
          }
        ]
      }
    }))
  ]

  depends_on = [kubernetes_secret.argocd_repo_creds]
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

# ArgoCD webhook secret for GitHub integration - Managed by Helm chart values
# The actual secret is managed by the Helm chart, this is just for webhook configuration
resource "kubernetes_secret" "argocd_webhook_secret" {
  count = var.enable_webhooks ? 1 : 0

  metadata {
    name      = "argocd-secret"
    namespace = kubernetes_namespace.argocd.metadata[0].name
    annotations = {
      "meta.helm.sh/release-name"      = "argocd"
      "meta.helm.sh/release-namespace" = "argocd"
    }
    labels = {
      "app.kubernetes.io/component"   = "server"
      "app.kubernetes.io/instance"    = "argocd"
      "app.kubernetes.io/managed-by"  = "Helm"
      "app.kubernetes.io/name"        = "argocd-secret"
      "app.kubernetes.io/part-of"     = "argocd"
      "app.kubernetes.io/version"     = "v3.1.7"
      "helm.sh/chart"                = "argo-cd-8.5.6"
    }
  }

  # Merge webhook secret with existing ArgoCD secrets
  data = merge({
    "webhook.github.secret" = var.github_webhook_secret
  }, {
    # Preserve any existing secrets that might be managed by Helm
    # These will be ignored in terraform state due to lifecycle rules
  })

  lifecycle {
    ignore_changes = [
      data["admin.password"],
      data["admin.passwordMtime"],
      data["server.secretkey"],
    ]
  }
}

# ArgoCD ConfigMap for webhook configuration - Merge with existing Helm-managed ConfigMap
resource "kubernetes_config_map" "argocd_cm" {
  count = var.enable_webhooks ? 1 : 0

  metadata {
    name      = "argocd-cm"
    namespace = kubernetes_namespace.argocd.metadata[0].name
    annotations = {
      "meta.helm.sh/release-name"      = "argocd"
      "meta.helm.sh/release-namespace" = "argocd"
    }
    labels = {
      "app.kubernetes.io/component"   = "server"
      "app.kubernetes.io/instance"    = "argocd"
      "app.kubernetes.io/managed-by"  = "Helm"
      "app.kubernetes.io/name"        = "argocd-cm"
      "app.kubernetes.io/part-of"     = "argocd"
      "app.kubernetes.io/version"     = "v3.1.7"
      "helm.sh/chart"                = "argo-cd-8.5.6"
    }
  }

  # Add webhook configuration to the existing ArgoCD ConfigMap
  data = merge({
    "webhook.maxPayloadSizeMB" = var.webhook_max_payload_size_mb
  }, {
    # These will be managed by lifecycle ignore_changes
  })

  lifecycle {
    ignore_changes = [
      # Ignore all other ConfigMap data that's managed by Helm
      data["admin.enabled"],
      data["application.instanceLabelKey"],
      data["application.sync.impersonation.enabled"],
      data["exec.enabled"],
      data["resource.customizations.ignoreResourceUpdates.ConfigMap"],
      data["resource.customizations.ignoreResourceUpdates.Endpoints"],
      data["resource.customizations.ignoreResourceUpdates.all"],
      data["resource.customizations.ignoreResourceUpdates.apps_ReplicaSet"],
      data["resource.customizations.ignoreResourceUpdates.argoproj.io_Application"],
      data["resource.customizations.ignoreResourceUpdates.argoproj.io_Rollout"],
      data["resource.customizations.ignoreResourceUpdates.autoscaling_HorizontalPodAutoscaler"],
      data["resource.customizations.ignoreResourceUpdates.discovery.k8s.io_EndpointSlice"],
      data["resource.exclusions"],
      data["server.rbac.log.enforce.enable"],
      data["statusbadge.enabled"],
      data["timeout.hard.reconciliation"],
      data["timeout.reconciliation"],
      data["url"],
    ]
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
  depends_on = [time_sleep.wait_for_argocd, kubernetes_secret.argocd_repo_creds]

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
resource "kubernetes_manifest" "helm_app_discovery" {
  count      = var.create_applicationset ? 1 : 0
  depends_on = [time_sleep.wait_for_argocd, kubernetes_secret.argocd_repo_creds]

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
          name = "{{ (index (splitList \"/\" .path.path) 1) }}-${var.environment}"
        }
        spec = {
          project = var.argocd_project
          
          # Use sources array which handles both Helm repos and Git repos cleanly
          sources = [
            {
              repoURL        = "{{ .spec.source.repoURL }}"
              targetRevision = "{{ .spec.source.targetRevision }}"
              chart          = "{{ .spec.source.chart | default \"\" }}"
              path           = "{{ .spec.source.path | default \"\" }}"
              helm = {
                values = "{{ .spec.source.helm.values | default \"\" }}"
              }
            }
          ]

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
