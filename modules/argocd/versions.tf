# ArgoCD Module Provider Requirements
# Defines the minimum Terraform version and required providers for ArgoCD module

terraform {
  required_version = ">= 1.0"
  
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~>2.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~>2.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~>4.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "~>0.9"
    }
  }
}
