output "namespace" {
  description = "MetalLB namespace"
  value       = kubernetes_namespace.metallb_system.metadata[0].name
}

output "helm_release_name" {
  description = "MetalLB Helm release name"
  value       = helm_release.metallb.name
}

output "helm_release_version" {
  description = "MetalLB Helm chart version"
  value       = helm_release.metallb.version
}

output "metallb_version" {
  description = "MetalLB application version"
  value       = var.metallb_version
}

output "ip_address_pools" {
  description = "Configured IP address pools"
  value = [
    for pool in var.ip_address_pools : {
      name      = pool.name
      addresses = pool.addresses
    }
  ]
}

output "l2_advertisements" {
  description = "L2 advertisement configurations"
  value = length(var.l2_advertisements) > 0 ? [
    for adv in var.l2_advertisements : {
      name             = adv.name
      ip_address_pools = lookup(adv, "ip_address_pools", [])
    }
  ] : []
}

output "bgp_enabled" {
  description = "Whether BGP mode is enabled"
  value       = var.enable_bgp
}

output "status_command" {
  description = "Command to check MetalLB status"
  value       = "kubectl get pods -n ${kubernetes_namespace.metallb_system.metadata[0].name}"
}

output "check_pools_command" {
  description = "Command to check IP address pools"
  value       = "kubectl get ipaddresspools -n ${kubernetes_namespace.metallb_system.metadata[0].name}"
}

output "check_services_command" {
  description = "Command to check LoadBalancer services"
  value       = "kubectl get svc --all-namespaces -o wide | grep LoadBalancer"
}

output "metallb_config_commands" {
  description = "Useful commands for MetalLB management"
  value = {
    check_controller = "kubectl get deployment controller -n ${kubernetes_namespace.metallb_system.metadata[0].name}"
    check_speaker    = "kubectl get daemonset speaker -n ${kubernetes_namespace.metallb_system.metadata[0].name}"
    view_logs        = "kubectl logs -l app.kubernetes.io/name=metallb -n ${kubernetes_namespace.metallb_system.metadata[0].name}"
    describe_pools   = "kubectl describe ipaddresspools -n ${kubernetes_namespace.metallb_system.metadata[0].name}"
    get_l2_ads       = "kubectl get l2advertisements -n ${kubernetes_namespace.metallb_system.metadata[0].name}"
  }
}

output "controller_service_account" {
  description = "MetalLB controller service account name"
  value       = kubernetes_service_account.controller.metadata[0].name
}

output "speaker_service_account" {
  description = "MetalLB speaker service account name"  
  value       = kubernetes_service_account.speaker.metadata[0].name
}

output "ip_address_pools" {
  description = "Configured IP address pools"
  value = {
    for i, pool in var.ip_address_pools : pool.name => {
      name            = pool.name
      addresses       = pool.addresses
      auto_assign     = pool.auto_assign
      avoid_buggy_ips = pool.avoid_buggy_ips
    }
  }
}

output "l2_advertisements" {
  description = "Configured L2 advertisements"
  value = {
    for i, adv in var.l2_advertisements : adv.name => {
      name             = adv.name
      ip_address_pools = adv.ip_address_pools
      interfaces       = adv.interfaces
    }
  }
}

output "bgp_peers" {
  description = "Configured BGP peers"
  value = var.enable_bgp ? {
    for i, peer in var.bgp_peers : peer.name => {
      name         = peer.name
      peer_address = peer.peer_address
      peer_asn     = peer.peer_asn
      my_asn       = peer.my_asn
    }
  } : {}
}

output "bgp_advertisements" {
  description = "Configured BGP advertisements"
  value = var.enable_bgp ? {
    for i, adv in var.bgp_advertisements : adv.name => {
      name             = adv.name
      ip_address_pools = adv.ip_address_pools
      communities      = adv.communities
    }
  } : {}
}

output "load_balancer_class" {
  description = "LoadBalancer class handled by MetalLB"
  value       = var.load_balancer_class
}

output "monitoring_endpoints" {
  description = "Monitoring endpoints for MetalLB components"
  value = var.enable_prometheus_monitoring ? {
    controller = {
      service   = "${kubernetes_deployment.controller.metadata[0].name}-metrics"
      port      = 7472
      path      = "/metrics"
      namespace = var.namespace
    }
    speaker = {
      service   = "${kubernetes_daemonset.speaker.metadata[0].name}-metrics" 
      port      = 7472
      path      = "/metrics"
      namespace = var.namespace
    }
  } : {}
}

output "secrets" {
  description = "Important secrets created by MetalLB"
  value = {
    memberlist_secret = kubernetes_secret.memberlist.metadata[0].name
    webhook_certs     = kubernetes_secret.webhook_certs.metadata[0].name
  }
  sensitive = true
}

output "custom_resource_definitions" {
  description = "Custom Resource Definitions created by MetalLB"
  value = [
    "ipaddresspools.metallb.io",
    "l2advertisements.metallb.io"
  ]
}

output "service_monitor_selector" {
  description = "Label selector for Prometheus ServiceMonitor"
  value = var.enable_prometheus_monitoring ? {
    matchLabels = {
      app = "metallb"
    }
  } : null
}

output "cluster_roles" {
  description = "Cluster roles created by MetalLB"
  value = [
    kubernetes_cluster_role.controller.metadata[0].name,
    kubernetes_cluster_role.speaker.metadata[0].name
  ]
}

output "cluster_role_bindings" {
  description = "Cluster role bindings created by MetalLB"
  value = [
    kubernetes_cluster_role_binding.controller.metadata[0].name,
    kubernetes_cluster_role_binding.speaker.metadata[0].name
  ]
}

output "ready" {
  description = "Indicates if MetalLB is ready for LoadBalancer services"
  value       = length(var.ip_address_pools) > 0
}

output "installation_notes" {
  description = "Post-installation notes and usage information"
  value = <<-EOT
    MetalLB has been successfully deployed to namespace '${var.namespace}'.
    
    Version: ${var.metallb_version}
    Mode: ${var.enable_bgp ? "BGP" : "Layer 2"}
    
    ${length(var.ip_address_pools) > 0 ? 
      "IP Address Pools configured: ${join(", ", [for pool in var.ip_address_pools : pool.name])}" :
      "⚠️  No IP address pools configured. Create IPAddressPool resources to enable LoadBalancer services."
    }
    
    ${length(var.l2_advertisements) > 0 ? 
      "L2 Advertisements configured: ${join(", ", [for adv in var.l2_advertisements : adv.name])}" :
      var.enable_layer2_mode && length(var.ip_address_pools) > 0 ? 
        "⚠️  No L2Advertisement configured. Create L2Advertisement resources for Layer 2 mode." : ""
    }
    
    ${var.enable_bgp && length(var.bgp_peers) > 0 ? 
      "BGP Peers configured: ${join(", ", [for peer in var.bgp_peers : peer.name])}" :
      var.enable_bgp ? "⚠️  BGP mode enabled but no BGP peers configured." : ""
    }
    
    To verify installation:
      kubectl -n ${var.namespace} get pods
      kubectl -n ${var.namespace} get ipaddresspools
      kubectl -n ${var.namespace} get l2advertisements
    
    To test LoadBalancer service:
      kubectl create service loadbalancer test --tcp=80:80
      kubectl get svc test
  EOT
}

output "troubleshooting_commands" {
  description = "Useful commands for troubleshooting MetalLB"
  value = {
    check_pods     = "kubectl -n ${var.namespace} get pods -l app=metallb"
    check_logs_controller = "kubectl -n ${var.namespace} logs -l app=metallb,component=controller"
    check_logs_speaker = "kubectl -n ${var.namespace} logs -l app=metallb,component=speaker"
    check_pools    = "kubectl -n ${var.namespace} get ipaddresspools"
    check_l2_ads   = "kubectl -n ${var.namespace} get l2advertisements"
    check_bgp_peers = var.enable_bgp ? "kubectl -n ${var.namespace} get bgppeers" : null
    check_events   = "kubectl -n ${var.namespace} get events --sort-by=.metadata.creationTimestamp"
    describe_controller = "kubectl -n ${var.namespace} describe deployment controller"
    describe_speaker = "kubectl -n ${var.namespace} describe daemonset speaker"
  }
}
