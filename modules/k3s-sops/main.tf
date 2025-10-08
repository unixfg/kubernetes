# K3s SOPS Module - Age-based secret encryption for Kubernetes
# Provides Age key integration for SOPS encryption using Kubernetes secrets

terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~>2.0"
    }
  }
}

# Fetch Age key from Kubernetes secret only if key is not provided directly
data "kubernetes_secret" "age_key" {
  count = var.age_key_content == "" ? 1 : 0

  metadata {
    name      = var.age_secret_name
    namespace = var.age_secret_namespace
  }
}

# Extract and validate Age key data
locals {
  # Use provided key if available, otherwise read from cluster secret
  age_key_raw = var.age_key_content != "" ? var.age_key_content : (
    length(data.kubernetes_secret.age_key) > 0 ? lookup(data.kubernetes_secret.age_key[0].data, var.age_key_field, "") : ""
  )

  # Age key is stored as-is (no base64 decoding needed)
  age_key = local.age_key_raw

  # Extract Age public key for SOPS configuration
  age_public_key = var.age_public_key != "" ? var.age_public_key : null
}

# Create a ConfigMap with Age configuration for SOPS operator consumption
resource "kubernetes_config_map" "sops_age_config" {
  metadata {
    name      = "sops-age-config"
    namespace = var.sops_operator_namespace
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      "app.kubernetes.io/component"  = "k3s-sops"
      "environment"                  = var.environment
    }
  }

  data = {
    # Age configuration for SOPS
    age_public_key        = local.age_public_key
    age_secret_name       = var.age_secret_name
    age_secret_namespace  = var.age_secret_namespace
    age_key_field         = var.age_key_field
    # Add SOPS creation rules template
    sops_creation_rules = jsonencode([
      {
        age = local.age_public_key
      }
    ])
  }
}

# Create a secret in the SOPS operator namespace containing the Age key
resource "kubernetes_secret" "sops_age" {
  metadata {
    name      = "sops-age"
    namespace = var.sops_operator_namespace
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      "app.kubernetes.io/component"  = "k3s-sops"
      "environment"                  = var.environment
    }
  }

  type = "Opaque"

  data = {
    "age.key" = local.age_key
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
          age = local.age_public_key
        }
      ]
    })
  }
}