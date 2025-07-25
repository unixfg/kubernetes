# MetalLB Load Balancer

This directory contains MetalLB configuration for providing LoadBalancer services in bare-metal Kubernetes clusters.

## Overview

MetalLB provides LoadBalancer services for Kubernetes clusters that don't run on supported cloud providers. It announces service IPs using either Layer 2 (ARP/NDP) or BGP protocols.

## Structure

```
metallb/
├── base/
│   ├── kustomization.yaml    # Base configuration
│   └── metallb.yaml          # Default ConfigMap with demo IP ranges
└── overlays/
    ├── dev/                  # Development environment
    ├── stage/                # Staging environment  
    └── prod/                 # Production environment
```

## Default Configuration

The base configuration provides:
- MetalLB v0.14.5 installation
- Layer 2 load balancing mode
- Demo IP range: `192.168.1.240-192.168.1.250`

### Environment-Specific IP Ranges

| Environment | IP Range |
|-------------|----------|
| dev | 192.168.1.240-192.168.1.245 |
| stage | 192.168.1.246-192.168.1.248 |
| prod | 192.168.1.249-192.168.1.250 |

## Deployment

Deploy MetalLB for a specific environment:

```bash
# Development
kubectl apply -k apps/metallb/overlays/dev

# Staging
kubectl apply -k apps/metallb/overlays/stage

# Production
kubectl apply -k apps/metallb/overlays/prod
```

## Verification

Check MetalLB installation:

```bash
# Check pods are running
kubectl get pods -n metallb-system

# Check configuration
kubectl get configmap -n metallb-system config -o yaml
```

## Customization

### Personal Deployment Override

To customize for your network without modifying tracked files, create a separate overlay:

```yaml
# personal-overlay/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - ../apps/metallb/overlays/dev  # or stage/prod

patchesStrategicMerge:
  - metallb-config.yaml

# personal-overlay/metallb-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: config
  namespace: metallb-system
data:
  config: |
    address-pools:
    - name: default
      protocol: layer2
      addresses:
      - YOUR_IP_RANGE_HERE  # e.g., 10.0.1.100-10.0.1.110
```

Then deploy with:
```bash
kubectl apply -k personal-overlay/
```

### BGP Mode

To use BGP instead of Layer 2, modify the configuration:

```yaml
data:
  config: |
    peers:
    - peer-address: 10.0.0.1
      peer-asn: 64501
      my-asn: 64500
    address-pools:
    - name: default
      protocol: bgp
      addresses:
      - 192.168.1.240/28
```

## Network Requirements

### Layer 2 Mode (Default)
- MetalLB nodes must be on the same Layer 2 network as the IP pool
- IP addresses must be available and not in use by DHCP
- Consider MAC address table limits on switches

### BGP Mode
- BGP router must be configured to peer with MetalLB
- Appropriate firewall rules for BGP (TCP port 179)
- Network routing configured for announced prefixes

## Troubleshooting

### Common Issues

1. **Service stays in Pending state**
   - Check MetalLB pods are running: `kubectl get pods -n metallb-system`
   - Verify IP range is correct for your network
   - Ensure IPs aren't in use elsewhere

2. **IP conflicts**
   - Use `nmap` or `ping` to verify IPs in range are available
   - Check DHCP server configuration
   - Ensure no other services are using the IP range

3. **Layer 2 connectivity issues**
   - Verify nodes are on same network segment
   - Check for VLAN configuration
   - Test connectivity between nodes and target IPs

### Debug Commands

```bash
# Check MetalLB logs
kubectl logs -n metallb-system -l app=metallb

# Check speaker pods specifically
kubectl logs -n metallb-system -l component=speaker

# Check controller logs
kubectl logs -n metallb-system -l component=controller

# View current configuration
kubectl get configmap -n metallb-system config -o yaml
```

## Security Considerations

- The metallb-system namespace uses privileged pod security standards
- MetalLB speaker pods require host networking access
- Consider network segmentation for production environments
- Regularly update MetalLB to the latest version for security patches

## References

- [MetalLB Documentation](https://metallb.universe.tf/)
- [MetalLB GitHub Repository](https://github.com/metallb/metallb)
- [Kubernetes LoadBalancer Services](https://kubernetes.io/docs/concepts/services-networking/service/#loadbalancer)