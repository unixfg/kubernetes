###############################################
# Kyverno CRDs Bootstrap Module
#
# Installs Kyverno CRDs using server-side apply to avoid
# the 262KB annotation size limit with large CRDs.
#
# After bootstrap, ArgoCD manages updates via GitOps.
###############################################

terraform {
  required_providers {
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.14"
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 3.0"
    }
  }
}

locals {
  # Kyverno CRD URLs from GitHub repository
  crd_base_url = "https://raw.githubusercontent.com/kyverno/kyverno/${var.kyverno_version}/config/crds/kyverno"

  # Core CRDs that are too large for standard kubectl apply
  core_crds = [
    "kyverno.io_clusterpolicies.yaml",
    "kyverno.io_policies.yaml",
  ]
}

# Fetch and apply clusterpolicies CRD
data "http" "clusterpolicies_crd" {
  url = "${local.crd_base_url}/kyverno.io_clusterpolicies.yaml"
}

resource "kubectl_manifest" "clusterpolicies" {
  yaml_body = data.http.clusterpolicies_crd.response_body

  server_side_apply = true
  wait              = true

  # Force conflicts to be resolved in favor of this manifest
  force_conflicts = true
}

# Fetch and apply policies CRD
data "http" "policies_crd" {
  url = "${local.crd_base_url}/kyverno.io_policies.yaml"
}

resource "kubectl_manifest" "policies" {
  yaml_body = data.http.policies_crd.response_body

  server_side_apply = true
  wait              = true

  # Force conflicts to be resolved in favor of this manifest
  force_conflicts = true
}
