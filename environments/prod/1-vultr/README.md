# VKS Cluster Configuration (1-vultr)

This Terraform configuration prepares an existing Vultr Kubernetes Service (VKS) cluster for GitOps platform deployment.

## Purpose

The `1-vultr` stage configures essential cluster components and validates cluster health before deploying ArgoCD and the SOPS Secrets Operator in the `2-platform` stage.

## Components Deployed

- **Metrics Server**: Enables `kubectl top` commands and provides resource metrics for HPA (Horizontal Pod Autoscaling)
- **Cluster Validation**: Ensures cluster connectivity and health
- **Cluster Info ConfigMap**: Stores cluster metadata for reference

## Prerequisites

1. **VKS Cluster**: You must have an existing Vultr Kubernetes Service cluster
2. **kubectl Access**: Ensure your `~/.kube/config` is configured to access the VKS cluster
3. **Terraform**: Version compatible with providers specified in `main.tf`

### Verify Cluster Access

```bash
# Ensure you're connected to the correct cluster
kubectl cluster-info
kubectl get nodes

# Should show your VKS nodes
```

## Deployment

### Step 1: Initialize Terraform

```bash
cd environments/prod/1-vultr
terraform init
```

### Step 2: Plan the Configuration

```bash
terraform plan -out main.tfplan
```

Review the plan to ensure:
- Metrics server will be deployed to `kube-system` namespace
- Cluster validation checks will run
- ConfigMap will be created with cluster info

### Step 3: Apply the Configuration

```bash
terraform apply main.tfplan
```

This will:
1. Validate cluster connectivity
2. Deploy metrics-server with HA configuration (2 replicas)
3. Wait for metrics-server to be ready
4. Create cluster info ConfigMap
5. Display next steps

### Step 4: Verify Deployment

```bash
# Check metrics-server pods
kubectl get pods -n kube-system -l app.kubernetes.io/name=metrics-server

# Verify metrics API (may take 1-2 minutes after deployment)
kubectl top nodes
kubectl top pods -A
```

## Configuration Options

Edit `terraform.tfvars` to customize:

- `kubeconfig_path`: Path to kubeconfig file (default: `~/.kube/config`)
- `metrics_server_version`: Helm chart version (default: `3.12.2`)
- `metrics_server_replicas`: Number of replicas for HA (default: `2`)

## Next Steps

After successful deployment:

1. **Navigate to platform stage**:
   ```bash
   cd ../2-platform
   ```

2. **Set required environment variables**:
   ```bash
   # Age encryption key for SOPS
   export TF_VAR_age_key_content="$(cat ~/infrastructure/age.key)"

   # GitHub App private key for ArgoCD
   export TF_VAR_github_app_private_key="$(cat ~/infrastructure/github.key)"
   ```

3. **Deploy GitOps platform**:
   ```bash
   terraform init
   terraform plan -out main.tfplan
   terraform apply main.tfplan
   ```

## Troubleshooting

### Cluster Connection Issues

If terraform fails with cluster connectivity errors:

```bash
# Verify kubectl can connect
kubectl cluster-info

# Check current context
kubectl config current-context

# Ensure you're using the VKS cluster context
kubectl config use-context <vks-cluster-context>
```

### Metrics Server Not Ready

If metrics-server pods are not becoming ready:

```bash
# Check pod status
kubectl get pods -n kube-system -l app.kubernetes.io/name=metrics-server

# View logs
kubectl logs -n kube-system -l app.kubernetes.io/name=metrics-server

# Common issues:
# - Node network issues
# - Insufficient resources on nodes
# - Kubelet TLS certificate issues
```

### Metrics API Not Responding

The metrics API can take 1-2 minutes to start collecting data:

```bash
# Wait and retry
kubectl top nodes

# If it continues failing, check metrics-server logs
kubectl logs -n kube-system deploy/metrics-server
```

## Cleanup

To remove the configuration (not recommended in production):

```bash
terraform destroy
```

**Note**: This will remove metrics-server but not delete the VKS cluster itself.

## Architecture Notes

### Why Separate from 2-platform?

The two-stage approach provides:
1. **Clear separation of concerns**: Infrastructure setup vs. application platform
2. **Dependency management**: Ensures metrics-server is ready before platform deployment
3. **Reusability**: Same pattern as AKS deployment (1-azure, 2-platform)
4. **Troubleshooting**: Easier to isolate issues between stages

### VKS Specifics

- **Storage**: VKS provides CSI storage classes (`vultr-block-storage-hdd`, `vultr-vfs-storage`)
- **Load Balancers**: VKS supports LoadBalancer service type
- **Node Management**: VKS automatically manages node updates and health
- **Metrics**: VKS does not include metrics-server by default (deployed by this configuration)

## Resources Created

| Resource Type | Name | Namespace | Purpose |
|--------------|------|-----------|---------|
| Helm Release | metrics-server | kube-system | Resource metrics collection |
| ConfigMap | vks-cluster-info | kube-system | Cluster metadata storage |

## Outputs

After successful apply, you'll see:

- `environment`: Environment name (prod)
- `node_count`: Number of nodes in cluster
- `kubernetes_version`: K8s version running
- `metrics_server_installed`: Confirmation of metrics-server deployment
- `cluster_type`: "vultr-vks"
- `next_steps`: Instructions for platform deployment

## Support

For issues specific to:
- **VKS**: Check [Vultr Kubernetes documentation](https://www.vultr.com/docs/vultr-kubernetes-engine/)
- **Metrics Server**: See [metrics-server GitHub](https://github.com/kubernetes-sigs/metrics-server)
- **Terraform**: Review provider documentation for kubernetes and helm
