###############################################
# Prod Environment - 1-vultr (VKS Cluster Configuration)
#
# This stage configures an existing Vultr Kubernetes Service (VKS) cluster
# with required components before deploying the GitOps platform.
#
# Components configured:
# - Metrics Server for resource monitoring
# - Cluster validation and health checks
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
    null = {
      source  = "hashicorp/null"
      version = "~>3.0"
    }
  }
}

# Use parent directory name (e.g., "prod") as environment name
locals {
  environment_name = basename(dirname(path.cwd))
  common_labels = {
    environment = local.environment_name
    managed     = "terraform"
  }
}

# Configure providers for VKS cluster
# Note: Ensure KUBECONFIG is set or ~/.kube/config points to VKS cluster
provider "kubernetes" {
  config_path = var.kubeconfig_path
}

provider "helm" {
  kubernetes {
    config_path = var.kubeconfig_path
  }
}

# Validate cluster connectivity
resource "null_resource" "validate_cluster" {
  provisioner "local-exec" {
    command = <<-EOT
      echo "Validating VKS cluster connectivity..."
      if ! kubectl cluster-info --request-timeout=10s 2>/dev/null; then
        echo "ERROR: Unable to connect to Kubernetes cluster"
        echo "Please ensure KUBECONFIG is set correctly for your VKS cluster"
        exit 1
      fi
      echo "Cluster connectivity validated!"
      kubectl get nodes
    EOT
    interpreter = ["bash", "-c"]
  }
}

# Get cluster information
data "kubernetes_nodes" "all" {
  depends_on = [null_resource.validate_cluster]
}

# Metrics Server namespace (usually kube-system)
# VKS typically doesn't include metrics-server by default
resource "helm_release" "metrics_server" {
  name       = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  version    = var.metrics_server_version
  namespace  = "kube-system"

  # Use values parameter to avoid comma parsing issues with args
  values = [
    yamlencode({
      replicas = var.metrics_server_replicas

      args = [
        "--cert-dir=/tmp",
        "--kubelet-preferred-address-types=InternalIP,ExternalIP,Hostname",
        "--kubelet-use-node-status-port",
        "--metric-resolution=15s"
      ]

      resources = {
        requests = {
          cpu    = "100m"
          memory = "200Mi"
        }
        limits = {
          cpu    = "500m"
          memory = "500Mi"
        }
      }
    })
  ]

  depends_on = [null_resource.validate_cluster]
}

# Wait for metrics server to be ready
resource "null_resource" "wait_for_metrics_server" {
  provisioner "local-exec" {
    command = <<-EOT
      echo "Waiting for metrics-server to be ready..."
      for i in {1..30}; do
        if kubectl wait --for=condition=ready pod \
          -l app.kubernetes.io/name=metrics-server \
          -n kube-system \
          --timeout=10s 2>/dev/null; then
          echo "Metrics server is ready!"

          # Verify metrics API is working (may take a few extra seconds)
          echo "Verifying metrics API..."
          for j in {1..12}; do
            if kubectl top nodes 2>/dev/null; then
              echo "Metrics API is working!"
              exit 0
            fi
            echo "Attempt $j/12: Metrics API not ready yet, waiting 5 seconds..."
            sleep 5
          done

          echo "WARNING: Metrics server is running but API not responding yet"
          echo "This may be normal - metrics collection can take 1-2 minutes"
          exit 0
        fi
        echo "Attempt $i/30: Metrics server not ready yet, waiting 10 seconds..."
        sleep 10
      done
      echo "ERROR: Metrics server failed to become ready"
      exit 1
    EOT
    interpreter = ["bash", "-c"]
  }

  depends_on = [helm_release.metrics_server]
}

# Create a ConfigMap with VKS cluster information for reference
resource "kubernetes_config_map" "vks_cluster_info" {
  metadata {
    name      = "vks-cluster-info"
    namespace = "kube-system"
    labels    = local.common_labels
  }

  data = {
    environment     = local.environment_name
    node_count      = length(data.kubernetes_nodes.all.nodes)
    kubernetes_version = try(data.kubernetes_nodes.all.nodes[0].status[0].node_info[0].kubelet_version, "unknown")
    cluster_type    = "vultr-vks"
    managed_by      = "terraform"
    terraform_stage = "1-vultr"
  }

  depends_on = [null_resource.validate_cluster]
}

# Output cluster readiness status
resource "null_resource" "cluster_ready" {
  provisioner "local-exec" {
    command = <<-EOT
      echo "========================================"
      echo "VKS Cluster Configuration Complete!"
      echo "========================================"
      echo "Environment: ${local.environment_name}"
      echo "Nodes: ${length(data.kubernetes_nodes.all.nodes)}"
      echo "Metrics Server: Deployed"
      echo ""
      echo "Next Steps:"
      echo "1. Proceed to environments/prod/2-platform"
      echo "2. Run: terraform init && terraform plan -out main.tfplan"
      echo "3. Review plan and apply: terraform apply main.tfplan"
      echo "========================================"
    EOT
    interpreter = ["bash", "-c"]
  }

  depends_on = [
    null_resource.wait_for_metrics_server,
    kubernetes_config_map.vks_cluster_info
  ]
}
