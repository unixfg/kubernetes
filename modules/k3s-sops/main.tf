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

# Fetch GPG key from Kubernetes secret only if keys are not provided directly
data "kubernetes_secret" "gpg_key" {
  count = var.gpg_private_key_content == "" ? 1 : 0

  metadata {
    name      = var.gpg_secret_name
    namespace = var.gpg_secret_namespace
  }
}

# Extract and validate GPG key data
locals {
  # Use provided keys if available, otherwise read from cluster secret
  # NOTE: Keys provided via variables are base64-encoded armor, need to decode first
  gpg_private_key_raw = var.gpg_private_key_content != "" ? var.gpg_private_key_content : (
    length(data.kubernetes_secret.gpg_key) > 0 ? lookup(data.kubernetes_secret.gpg_key[0].data, var.gpg_private_key_field, "") : ""
  )
  gpg_public_key_raw = var.gpg_public_key_content != "" ? var.gpg_public_key_content : (
    length(data.kubernetes_secret.gpg_key) > 0 ? lookup(data.kubernetes_secret.gpg_key[0].data, var.gpg_public_key_field, "") : ""
  )

  # Decode the base64-encoded armor to get actual GPG armored keys
  # The terraform-with-gpg.sh script exports keys as base64(armor), we need just armor
  gpg_private_key = var.gpg_private_key_content != "" ? base64decode(local.gpg_private_key_raw) : local.gpg_private_key_raw
  gpg_public_key  = var.gpg_public_key_content != "" ? base64decode(local.gpg_public_key_raw) : local.gpg_public_key_raw

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