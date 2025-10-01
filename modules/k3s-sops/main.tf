# K3s SOPS Module - GPG-based secret encryption for Kubernetes
# Provides GPG key integration for SOPS encryption using Kubernetes secrets

terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~>2.0"
    }
  }
}

# Fetch GPG key from Kubernetes secret
data "kubernetes_secret" "gpg_key" {
  metadata {
    name      = var.gpg_secret_name
    namespace = var.gpg_secret_namespace
  }
}

# Extract and validate GPG key data
locals {
  gpg_private_key = lookup(data.kubernetes_secret.gpg_key.data, var.gpg_private_key_field, "")
  gpg_public_key  = lookup(data.kubernetes_secret.gpg_key.data, var.gpg_public_key_field, "")

  # Extract GPG key fingerprint from the public key for SOPS configuration
  gpg_fingerprint = var.gpg_fingerprint != "" ? var.gpg_fingerprint : null
}

# Create a ConfigMap with GPG configuration for SOPS operator consumption
resource "kubernetes_config_map" "sops_gpg_config" {
  metadata {
    name      = "sops-gpg-config"
    namespace = var.sops_operator_namespace
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      "app.kubernetes.io/component"  = "k3s-sops"
      "environment"                  = var.environment
    }
  }

  data = {
    # GPG configuration for SOPS
    gpg_fingerprint    = local.gpg_fingerprint
    gpg_secret_name    = var.gpg_secret_name
    gpg_secret_namespace = var.gpg_secret_namespace
    gpg_private_key_field = var.gpg_private_key_field
    # Add SOPS creation rules template
    sops_creation_rules = jsonencode([
      {
        pgp = local.gpg_fingerprint
      }
    ])
  }
}

# Create a secret in the SOPS operator namespace containing the GPG keys
resource "kubernetes_secret" "sops_gpg_keys" {
  metadata {
    name      = "sops-gpg-keys"
    namespace = var.sops_operator_namespace
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      "app.kubernetes.io/component"  = "k3s-sops"
      "environment"                  = var.environment
    }
  }

  type = "Opaque"

  data = {
    "private.asc" = local.gpg_private_key
    "public.asc"  = local.gpg_public_key
  }

  depends_on = [data.kubernetes_secret.gpg_key]
}

# Create SOPS configuration file as a ConfigMap
resource "kubernetes_config_map" "sops_config" {
  count = var.create_sops_config ? 1 : 0

  metadata {
    name      = "sops-config"
    namespace = var.sops_operator_namespace
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      "app.kubernetes.io/component"  = "k3s-sops"
      "environment"                  = var.environment
    }
  }

  data = {
    ".sops.yaml" = yamlencode({
      creation_rules = [
        {
          pgp = local.gpg_fingerprint
        }
      ]
    })
  }
}