# MetalLB Module

This module deploys MetalLB using the **official Helm chart**, providing network load balancer functionality for Kubernetes clusters.

## Features

- Uses official MetalLB Helm chart from https://metallb.github.io/metallb
- Supports both Layer 2 (ARP/NDP) and BGP modes
- Configurable IP address pools with automatic assignment
- Resource limits and node selectors
- Prometheus metrics support
- Proper CRD management through Helm

## Usage

### Layer 2 Mode (Default)
```hcl
module "metallb" {
  source = "../../modules/metallb"
  
  namespace                   = "metallb-system"
  metallb_version            = "v0.15.2"
  metallb_helm_chart_version = "0.15.2"
  enable_bgp                 = false
  
  ip_address_pools = [
    {
      name      = "default-pool"
      addresses = ["10.240.0.100-10.240.0.150"]
    }
  ]
  
  l2_advertisements = [
    {
      name             = "default"
      ip_address_pools = ["default-pool"]
    }
  ]
}
```

### BGP Mode
```hcl
module "metallb" {
  source = "../../modules/metallb"
  
  enable_bgp = true
  
  ip_address_pools = [
    {
      name      = "bgp-pool"
      addresses = ["192.168.1.240/28"]
    }
  ]
  
  bgp_peers = [
    {
      name         = "router1"
      my_asn       = 64512
      peer_asn     = 64512
      peer_address = "192.168.1.1"
    }
  ]
  
  bgp_advertisements = [
    {
      name             = "bgp-adv"
      ip_address_pools = ["bgp-pool"]
    }
  ]
}
```

## Key Variables

| Name | Description | Default |
|------|-------------|---------|
| `metallb_version` | MetalLB application version | `v0.15.2` |
| `metallb_helm_chart_version` | Helm chart version | `0.15.2` |
| `enable_bgp` | Enable BGP mode | `false` |
| `ip_address_pools` | IP address pools configuration | `[]` |
| `l2_advertisements` | Layer 2 advertisements | `[]` |
| `bgp_peers` | BGP peer configurations | `[]` |
| `bgp_advertisements` | BGP advertisements | `[]` |

## Benefits of Helm-based Deployment

1. **Official Support**: Uses the official MetalLB Helm chart
2. **CRD Management**: Helm handles CRD installation and upgrades
3. **Version Management**: Easy upgrades through Helm
4. **Configuration**: Centralized values configuration
5. **Dependencies**: Proper dependency management
6. **Rollbacks**: Helm rollback capabilities

## Testing LoadBalancer Services

After deployment, test with a simple service:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: test-lb
spec:
  type: LoadBalancer
  ports:
  - port: 80
    targetPort: 8080
  selector:
    app: test-app
```

Check the assigned IP:
```bash
kubectl get svc test-lb
```
