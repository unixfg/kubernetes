# MetalLB Load Balancer Module using Official Helm Chart

# Create namespace for MetalLB
resource "kubernetes_namespace" "metallb_system" {
  metadata {
    name = var.namespace
    labels = {
      "pod-security.kubernetes.io/enforce" = "privileged"
      "pod-security.kubernetes.io/audit"   = "privileged"
      "pod-security.kubernetes.io/warn"    = "privileged"
    }
  }
}

# Deploy MetalLB using official Helm chart
resource "helm_release" "metallb" {
  name       = "metallb"
  namespace  = kubernetes_namespace.metallb_system.metadata[0].name
  repository = "https://metallb.github.io/metallb"
  chart      = "metallb"
  version    = var.metallb_helm_chart_version

  # Wait for the deployment to be ready
  wait          = true
  wait_for_jobs = true
  timeout       = 600

  # Force update if needed
  force_update = true

  # Values for the Helm chart
  values = [
    yamlencode({
      controller = {
        image = {
          tag = var.metallb_version
        }
        resources = var.controller_resources
        nodeSelector = var.controller_node_selector
        tolerations  = var.controller_tolerations
      }
      speaker = {
        image = {
          tag = var.metallb_version
        }
        resources    = var.speaker_resources
        nodeSelector = var.speaker_node_selector
        tolerations  = var.speaker_tolerations
        # Enable/disable FRR mode (BGP support)
        frr = {
          enabled = var.enable_bgp
        }
      }
      # CRDs are included in the chart
      crds = {
        enabled = true
      }
      # Prometheus monitoring
      prometheus = {
        scrapeAnnotations = var.enable_prometheus_metrics
        metricsPort      = 7472
        rbacPrometheus   = var.enable_prometheus_metrics
        serviceAccount   = var.prometheus_service_account
      }
    })
  ]

  depends_on = [kubernetes_namespace.metallb_system]
}

# Wait for MetalLB to be fully deployed before creating pools
resource "time_sleep" "wait_for_metallb" {
  depends_on = [helm_release.metallb]
  create_duration = "30s"
}

# Create IP Address Pools
resource "kubernetes_manifest" "ip_address_pool" {
  count = length(var.ip_address_pools)

  manifest = {
    apiVersion = "metallb.io/v1beta1"
    kind       = "IPAddressPool"
    metadata = {
      name      = var.ip_address_pools[count.index].name
      namespace = kubernetes_namespace.metallb_system.metadata[0].name
    }
    spec = {
      addresses     = var.ip_address_pools[count.index].addresses
      autoAssign    = lookup(var.ip_address_pools[count.index], "auto_assign", true)
      avoidBuggyIPs = lookup(var.ip_address_pools[count.index], "avoid_buggy_ips", true)
    }
  }

  depends_on = [time_sleep.wait_for_metallb]
}

# Create L2 Advertisements (for Layer 2 mode)
resource "kubernetes_manifest" "l2_advertisement" {
  count = length(var.l2_advertisements)

  manifest = {
    apiVersion = "metallb.io/v1beta1"
    kind       = "L2Advertisement"
    metadata = {
      name      = var.l2_advertisements[count.index].name
      namespace = kubernetes_namespace.metallb_system.metadata[0].name
    }
    spec = merge(
      {
        ipAddressPools = lookup(var.l2_advertisements[count.index], "ip_address_pools", [])
      },
      lookup(var.l2_advertisements[count.index], "node_selectors", null) != null ? {
        nodeSelectors = var.l2_advertisements[count.index].node_selectors
      } : {},
      lookup(var.l2_advertisements[count.index], "interfaces", null) != null && length(var.l2_advertisements[count.index].interfaces) > 0 ? {
        interfaces = var.l2_advertisements[count.index].interfaces
      } : {}
    )
  }

  depends_on = [
    time_sleep.wait_for_metallb,
    kubernetes_manifest.ip_address_pool
  ]
}

# Create BGP Advertisements (if BGP is enabled)
resource "kubernetes_manifest" "bgp_advertisement" {
  count = var.enable_bgp ? length(var.bgp_advertisements) : 0

  manifest = {
    apiVersion = "metallb.io/v1beta1"
    kind       = "BGPAdvertisement"
    metadata = {
      name      = var.bgp_advertisements[count.index].name
      namespace = kubernetes_namespace.metallb_system.metadata[0].name
    }
    spec = merge(
      {
        ipAddressPools = lookup(var.bgp_advertisements[count.index], "ip_address_pools", [])
      },
      lookup(var.bgp_advertisements[count.index], "aggregation_length", null) != null ? {
        aggregationLength = var.bgp_advertisements[count.index].aggregation_length
      } : {},
      lookup(var.bgp_advertisements[count.index], "localpref", null) != null ? {
        localPref = var.bgp_advertisements[count.index].localpref
      } : {},
      lookup(var.bgp_advertisements[count.index], "communities", null) != null ? {
        communities = var.bgp_advertisements[count.index].communities
      } : {},
      lookup(var.bgp_advertisements[count.index], "peers", null) != null ? {
        peers = var.bgp_advertisements[count.index].peers
      } : {}
    )
  }

  depends_on = [
    time_sleep.wait_for_metallb,
    kubernetes_manifest.ip_address_pool
  ]
}

# Create BGP Peers (if BGP is enabled)
resource "kubernetes_manifest" "bgp_peer" {
  count = var.enable_bgp ? length(var.bgp_peers) : 0

  manifest = {
    apiVersion = "metallb.io/v1beta2"
    kind       = "BGPPeer"
    metadata = {
      name      = var.bgp_peers[count.index].name
      namespace = kubernetes_namespace.metallb_system.metadata[0].name
    }
    spec = merge(
      {
        myASN       = var.bgp_peers[count.index].my_asn
        peerASN     = var.bgp_peers[count.index].peer_asn
        peerAddress = var.bgp_peers[count.index].peer_address
      },
      lookup(var.bgp_peers[count.index], "peer_port", null) != null ? {
        peerPort = var.bgp_peers[count.index].peer_port
      } : {},
      lookup(var.bgp_peers[count.index], "source_address", null) != null ? {
        sourceAddress = var.bgp_peers[count.index].source_address
      } : {},
      lookup(var.bgp_peers[count.index], "node_selectors", null) != null ? {
        nodeSelectors = var.bgp_peers[count.index].node_selectors
      } : {},
      lookup(var.bgp_peers[count.index], "password", null) != null ? {
        password = var.bgp_peers[count.index].password
      } : {},
      lookup(var.bgp_peers[count.index], "hold_time", null) != null ? {
        holdTime = var.bgp_peers[count.index].hold_time
      } : {},
      lookup(var.bgp_peers[count.index], "keepalive_time", null) != null ? {
        keepaliveTime = var.bgp_peers[count.index].keepalive_time
      } : {},
      lookup(var.bgp_peers[count.index], "router_id", null) != null ? {
        routerID = var.bgp_peers[count.index].router_id
      } : {}
    )
  }

  depends_on = [time_sleep.wait_for_metallb]
}

# MetalLB Controller Deployment
resource "kubernetes_deployment" "controller" {
  metadata {
    name      = "controller"
    namespace = var.namespace
    labels = {
      app       = "metallb"
      component = "controller"
    }
  }
  
  spec {
    replicas = 1
    selector {
      match_labels = {
        app       = "metallb"
        component = "controller"
      }
    }
    
    template {
      metadata {
        labels = {
          app       = "metallb"
          component = "controller"
        }
        annotations = {
          "prometheus.io/scrape" = "true"
          "prometheus.io/port"   = "7472"
        }
      }
      
      spec {
        service_account_name = kubernetes_service_account.controller.metadata[0].name
        node_selector        = var.controller_node_selector
        
        security_context {
          run_as_non_root = true
          run_as_user     = 65534
          fs_group        = 65534
        }
        
        container {
          name  = "controller"
          image = "quay.io/metallb/controller:${var.metallb_version}"
          
          args = [
            "--port=7472",
            "--log-level=${var.log_level}",
            "--webhook-mode=enabled"
          ]
          
          env {
            name = "METALLB_ML_SECRET_NAME"
            value = kubernetes_secret.memberlist.metadata[0].name
          }
          
          env {
            name = "METALLB_DEPLOYMENT"
            value = "controller"
          }
          
          port {
            name           = "monitoring"
            container_port = 7472
          }
          
          port {
            name           = "webhook"
            container_port = 9443
            protocol       = "TCP"
          }
          
          liveness_probe {
            http_get {
              path = "/metrics"
              port = "monitoring"
            }
            initial_delay_seconds = 10
            period_seconds        = 10
            timeout_seconds       = 1
            success_threshold     = 1
            failure_threshold     = 3
          }
          
          readiness_probe {
            http_get {
              path = "/metrics"
              port = "monitoring"
            }
            initial_delay_seconds = 10
            period_seconds        = 10
            timeout_seconds       = 1
            success_threshold     = 1
            failure_threshold     = 3
          }
          
          resources {
            limits = {
              cpu    = var.controller_resources.limits.cpu
              memory = var.controller_resources.limits.memory
            }
            requests = {
              cpu    = var.controller_resources.requests.cpu
              memory = var.controller_resources.requests.memory
            }
          }
          
          security_context {
            allow_privilege_escalation = false
            capabilities {
              drop = ["ALL"]
            }
            read_only_root_filesystem = true
          }
          
          volume_mount {
            name       = "webhook-certs"
            mount_path = "/tmp/k8s-webhook-server/serving-certs"
            read_only  = true
          }
        }
        
        volume {
          name = "webhook-certs"
          secret {
            secret_name = "webhook-server-certs"
          }
        }
        
        termination_grace_period_seconds = 0
      }
    }
  }
  
  depends_on = [
    kubernetes_namespace.metallb_system,
    kubernetes_service_account.controller,
    kubernetes_secret.memberlist
  ]
}

# MetalLB Speaker DaemonSet
resource "kubernetes_daemonset" "speaker" {
  metadata {
    name      = "speaker"
    namespace = var.namespace
    labels = {
      app       = "metallb"
      component = "speaker"
    }
  }
  
  spec {
    selector {
      match_labels = {
        app       = "metallb"
        component = "speaker"
      }
    }
    
    template {
      metadata {
        labels = {
          app       = "metallb"
          component = "speaker"
        }
        annotations = {
          "prometheus.io/scrape" = "true"
          "prometheus.io/port"   = "7472"
        }
      }
      
      spec {
        service_account_name = kubernetes_service_account.speaker.metadata[0].name
        host_network         = true
        node_selector        = var.speaker_node_selector
        
        toleration {
          key      = "node-role.kubernetes.io/master"
          operator = "Exists"
          effect   = "NoSchedule"
        }
        
        toleration {
          key      = "node-role.kubernetes.io/control-plane"
          operator = "Exists"
          effect   = "NoSchedule"
        }
        
        dynamic "toleration" {
          for_each = var.speaker_tolerations
          content {
            key               = toleration.value.key
            operator          = toleration.value.operator
            value             = toleration.value.value
            effect            = toleration.value.effect
            toleration_seconds = toleration.value.toleration_seconds
          }
        }
        
        container {
          name  = "speaker"
          image = "quay.io/metallb/speaker:${var.metallb_version}"
          
          args = [
            "--port=7472",
            "--log-level=${var.log_level}"
          ]
          
          env {
            name = "METALLB_NODE_NAME"
            value_from {
              field_ref {
                field_path = "spec.nodeName"
              }
            }
          }
          
          env {
            name = "METALLB_HOST"
            value_from {
              field_ref {
                field_path = "status.hostIP"
              }
            }
          }
          
          env {
            name = "METALLB_ML_BIND_ADDR"
            value_from {
              field_ref {
                field_path = "status.podIP"
              }
            }
          }
          
          env {
            name = "METALLB_ML_LABELS"
            value = "app=metallb,component=speaker"
          }
          
          env {
            name = "METALLB_ML_SECRET_KEY_PATH"
            value = "/etc/ml_secret_key"
          }
          
          env {
            name = "METALLB_DEPLOYMENT"
            value = "speaker"
          }
          
          port {
            name           = "monitoring"
            container_port = 7472
          }
          
          port {
            name           = "memberlist-tcp"
            container_port = 7946
          }
          
          port {
            name           = "memberlist-udp"
            container_port = 7946
            protocol       = "UDP"
          }
          
          liveness_probe {
            http_get {
              path = "/metrics"
              port = "monitoring"
            }
            initial_delay_seconds = 10
            period_seconds        = 10
            timeout_seconds       = 1
            success_threshold     = 1
            failure_threshold     = 3
          }
          
          readiness_probe {
            http_get {
              path = "/metrics"
              port = "monitoring"
            }
            initial_delay_seconds = 10
            period_seconds        = 10
            timeout_seconds       = 1
            success_threshold     = 1
            failure_threshold     = 3
          }
          
          resources {
            limits = {
              cpu    = var.speaker_resources.limits.cpu
              memory = var.speaker_resources.limits.memory
            }
            requests = {
              cpu    = var.speaker_resources.requests.cpu
              memory = var.speaker_resources.requests.memory
            }
          }
          
          security_context {
            allow_privilege_escalation = false
            capabilities {
              add  = ["NET_RAW"]
              drop = ["ALL"]
            }
            read_only_root_filesystem = true
          }
          
          volume_mount {
            name       = "memberlist"
            mount_path = "/etc/ml_secret_key"
            sub_path   = "secretkey"
            read_only  = true
          }
        }
        
        volume {
          name = "memberlist"
          secret {
            secret_name  = kubernetes_secret.memberlist.metadata[0].name
            default_mode = "0400"
          }
        }
        
        termination_grace_period_seconds = 2
      }
    }
  }
  
  depends_on = [
    kubernetes_namespace.metallb_system,
    kubernetes_service_account.speaker,
    kubernetes_secret.memberlist
  ]
}

# Service Account for Controller
resource "kubernetes_service_account" "controller" {
  metadata {
    name      = "controller"
    namespace = var.namespace
    labels = {
      app = "metallb"
    }
  }
  
  depends_on = [kubernetes_namespace.metallb_system]
}

# Service Account for Speaker
resource "kubernetes_service_account" "speaker" {
  metadata {
    name      = "speaker"
    namespace = var.namespace
    labels = {
      app = "metallb"
    }
  }
  
  depends_on = [kubernetes_namespace.metallb_system]
}

# ClusterRole for Controller
resource "kubernetes_cluster_role" "controller" {
  metadata {
    name = "metallb-system:controller"
    labels = {
      app = "metallb"
    }
  }
  
  rule {
    api_groups = [""]
    resources  = ["services", "namespaces"]
    verbs      = ["get", "list", "watch"]
  }
  
  rule {
    api_groups = [""]
    resources  = ["nodes"]
    verbs      = ["get", "list", "watch"]
  }
  
  rule {
    api_groups = [""]
    resources  = ["services/status"]
    verbs      = ["update"]
  }
  
  rule {
    api_groups = [""]
    resources  = ["events"]
    verbs      = ["create", "patch"]
  }
  
  rule {
    api_groups     = ["policy"]
    resources      = ["podsecuritypolicies"]
    resource_names = ["controller"]
    verbs          = ["use"]
  }
  
  rule {
    api_groups = ["metallb.io"]
    resources  = ["addresspools"]
    verbs      = ["get", "list", "watch"]
  }
  
  rule {
    api_groups = ["metallb.io"]
    resources  = ["bfdprofiles"]
    verbs      = ["get", "list", "watch"]
  }
  
  rule {
    api_groups = ["metallb.io"]
    resources  = ["bgpadvertisements"]
    verbs      = ["get", "list", "watch"]
  }
  
  rule {
    api_groups = ["metallb.io"]
    resources  = ["bgppeers"]
    verbs      = ["get", "list", "watch"]
  }
  
  rule {
    api_groups = ["metallb.io"]
    resources  = ["communities"]
    verbs      = ["get", "list", "watch"]
  }
  
  rule {
    api_groups = ["metallb.io"]
    resources  = ["ipaddresspools"]
    verbs      = ["get", "list", "watch"]
  }
  
  rule {
    api_groups = ["metallb.io"]
    resources  = ["l2advertisements"]
    verbs      = ["get", "list", "watch"]
  }
}

# ClusterRole for Speaker
resource "kubernetes_cluster_role" "speaker" {
  metadata {
    name = "metallb-system:speaker"
    labels = {
      app = "metallb"
    }
  }
  
  rule {
    api_groups = [""]
    resources  = ["services", "endpoints", "nodes"]
    verbs      = ["get", "list", "watch"]
  }
  
  rule {
    api_groups = ["discovery.k8s.io"]
    resources  = ["endpointslices"]
    verbs      = ["get", "list", "watch"]
  }
  
  rule {
    api_groups = [""]
    resources  = ["events"]
    verbs      = ["create", "patch"]
  }
  
  rule {
    api_groups     = ["policy"]
    resources      = ["podsecuritypolicies"]
    resource_names = ["speaker"]
    verbs          = ["use"]
  }
  
  rule {
    api_groups = ["metallb.io"]
    resources  = ["addresspools"]
    verbs      = ["get", "list", "watch"]
  }
  
  rule {
    api_groups = ["metallb.io"]
    resources  = ["bfdprofiles"]
    verbs      = ["get", "list", "watch"]
  }
  
  rule {
    api_groups = ["metallb.io"]
    resources  = ["bgpadvertisements"]
    verbs      = ["get", "list", "watch"]
  }
  
  rule {
    api_groups = ["metallb.io"]
    resources  = ["bgppeers"]
    verbs      = ["get", "list", "watch"]
  }
  
  rule {
    api_groups = ["metallb.io"]
    resources  = ["communities"]
    verbs      = ["get", "list", "watch"]
  }
  
  rule {
    api_groups = ["metallb.io"]
    resources  = ["ipaddresspools"]
    verbs      = ["get", "list", "watch"]
  }
  
  rule {
    api_groups = ["metallb.io"]
    resources  = ["l2advertisements"]
    verbs      = ["get", "list", "watch"]
  }
}

# ClusterRoleBinding for Controller
resource "kubernetes_cluster_role_binding" "controller" {
  metadata {
    name = "metallb-system:controller"
    labels = {
      app = "metallb"
    }
  }
  
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.controller.metadata[0].name
  }
  
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.controller.metadata[0].name
    namespace = var.namespace
  }
}

# ClusterRoleBinding for Speaker
resource "kubernetes_cluster_role_binding" "speaker" {
  metadata {
    name = "metallb-system:speaker"
    labels = {
      app = "metallb"
    }
  }
  
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.speaker.metadata[0].name
  }
  
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.speaker.metadata[0].name
    namespace = var.namespace
  }
}

# Role for Controller
resource "kubernetes_role" "controller" {
  metadata {
    name      = "controller"
    namespace = var.namespace
  }
  
  rule {
    api_groups = [""]
    resources  = ["secrets"]
    verbs      = ["create", "get", "list", "watch"]
  }
  
  rule {
    api_groups = [""]
    resources  = ["secrets"]
    verbs      = ["list"]
  }
  
  rule {
    api_groups     = ["apps"]
    resources      = ["deployments"]
    resource_names = ["controller"]
    verbs          = ["get"]
  }
  
  rule {
    api_groups = ["metallb.io"]
    resources  = ["bgppeers"]
    verbs      = ["get", "list"]
  }
  
  rule {
    api_groups = ["metallb.io"]
    resources  = ["addresspools", "communities", "bfdprofiles"]
    verbs      = ["create", "delete", "get", "list", "patch", "update", "watch"]
  }
  
  rule {
    api_groups = ["metallb.io"]
    resources  = ["ipaddresspools", "bgpadvertisements", "l2advertisements"]
    verbs      = ["create", "delete", "get", "list", "patch", "update", "watch"]
  }
}

# Role for Speaker
resource "kubernetes_role" "speaker" {
  metadata {
    name      = "speaker"
    namespace = var.namespace
  }
  
  rule {
    api_groups = [""]
    resources  = ["secrets"]
    verbs      = ["get", "list", "watch"]
  }
  
  rule {
    api_groups = [""]
    resources  = ["configmaps"]
    verbs      = ["get", "list", "watch"]
  }
  
  rule {
    api_groups = ["metallb.io"]
    resources  = ["addresspools"]
    verbs      = ["get", "list", "watch"]
  }
  
  rule {
    api_groups = ["metallb.io"]
    resources  = ["bfdprofiles"]
    verbs      = ["get", "list", "watch"]
  }
  
  rule {
    api_groups = ["metallb.io"]
    resources  = ["bgpadvertisements"]
    verbs      = ["get", "list", "watch"]
  }
  
  rule {
    api_groups = ["metallb.io"]
    resources  = ["bgppeers"]
    verbs      = ["get", "list", "watch"]
  }
  
  rule {
    api_groups = ["metallb.io"]
    resources  = ["l2advertisements"]
    verbs      = ["get", "list", "watch"]
  }
  
  rule {
    api_groups = ["metallb.io"]
    resources  = ["communities"]
    verbs      = ["get", "list", "watch"]
  }
  
  rule {
    api_groups = ["metallb.io"]
    resources  = ["ipaddresspools"]
    verbs      = ["get", "list", "watch"]
  }
}

# RoleBinding for Controller
resource "kubernetes_role_binding" "controller" {
  metadata {
    name      = "controller"
    namespace = var.namespace
  }
  
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role.controller.metadata[0].name
  }
  
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.controller.metadata[0].name
    namespace = var.namespace
  }
}

# RoleBinding for Speaker
resource "kubernetes_role_binding" "speaker" {
  metadata {
    name      = "speaker"
    namespace = var.namespace
  }
  
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role.speaker.metadata[0].name
  }
  
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.speaker.metadata[0].name
    namespace = var.namespace
  }
}

# Secret for memberlist
resource "random_password" "memberlist_key" {
  length  = 128
  special = false
}

resource "kubernetes_secret" "memberlist" {
  metadata {
    name      = "memberlist"
    namespace = var.namespace
  }
  
  data = {
    secretkey = base64encode(random_password.memberlist_key.result)
  }
  
  depends_on = [kubernetes_namespace.metallb_system]
}

# Webhook TLS Certificate Secret
resource "tls_private_key" "webhook" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "webhook" {
  private_key_pem = tls_private_key.webhook.private_key_pem
  
  subject {
    common_name  = "webhook-service.${var.namespace}.svc"
    organization = "metallb"
  }
  
  dns_names = [
    "webhook-service",
    "webhook-service.${var.namespace}",
    "webhook-service.${var.namespace}.svc",
    "webhook-service.${var.namespace}.svc.cluster.local"
  ]
  
  validity_period_hours = 8760 # 1 year
  
  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}

resource "kubernetes_secret" "webhook_certs" {
  metadata {
    name      = "webhook-server-certs"
    namespace = var.namespace
  }
  
  data = {
    "tls.crt" = tls_self_signed_cert.webhook.cert_pem
    "tls.key" = tls_private_key.webhook.private_key_pem
  }
  
  type = "kubernetes.io/tls"
  
  depends_on = [kubernetes_namespace.metallb_system]
}

# Webhook Service
resource "kubernetes_service" "webhook_service" {
  metadata {
    name      = "webhook-service"
    namespace = var.namespace
  }
  
  spec {
    port {
      port        = 443
      protocol    = "TCP"
      target_port = 9443
    }
    
    selector = {
      app       = "metallb"
      component = "controller"
    }
  }
  
  depends_on = [kubernetes_namespace.metallb_system]
}

# Custom Resource Definitions
resource "kubernetes_manifest" "ipaddresspool_crd" {
  manifest = {
    apiVersion = "apiextensions.k8s.io/v1"
    kind       = "CustomResourceDefinition"
    
    metadata = {
      annotations = {
        "controller-gen.kubebuilder.io/version" = "v0.11.1"
      }
      name = "ipaddresspools.metallb.io"
    }
    
    spec = {
      group = "metallb.io"
      names = {
        kind     = "IPAddressPool"
        listKind = "IPAddressPoolList"
        plural   = "ipaddresspools"
        singular = "ipaddresspool"
      }
      scope = "Namespaced"
      versions = [
        {
          name    = "v1beta1"
          served  = true
          storage = true
          schema = {
            openAPIV3Schema = {
              description = "IPAddressPool represents a pool of IP addresses that can be allocated to LoadBalancer services."
              type        = "object"
              properties = {
                apiVersion = {
                  description = "APIVersion defines the versioned schema of this representation of an object."
                  type        = "string"
                }
                kind = {
                  description = "Kind is a string value representing the REST resource this object represents."
                  type        = "string"
                }
                metadata = {
                  type = "object"
                }
                spec = {
                  description = "IPAddressPoolSpec defines the desired state of IPAddressPool."
                  type        = "object"
                  properties = {
                    addresses = {
                      description = "A list of IP address ranges over which MetalLB has authority."
                      type        = "array"
                      items = {
                        type = "string"
                      }
                    }
                    autoAssign = {
                      description = "AutoAssign flag used to prevent MetalLB from automatic allocation for a pool."
                      type        = "boolean"
                      default     = true
                    }
                    avoidBuggyIPs = {
                      description = "AvoidBuggyIPs prevents addresses ending with .0 and .255 to be used by a pool."
                      type        = "boolean"
                      default     = false
                    }
                    serviceAllocation = {
                      description = "AllocateTo makes ip pool allocation to specific namespace and/or service."
                      type        = "object"
                      properties = {
                        namespaces = {
                          description = "Namespaces list of namespace(s) on which ip pool can be attached."
                          type        = "array"
                          items = {
                            type = "string"
                          }
                        }
                        namespaceSelectors = {
                          description = "NamespaceSelectors list of label selectors to select namespace(s) on which ip pool can be attached."
                          type        = "array"
                          items = {
                            description = "A label selector is a label query over a set of resources."
                            type        = "object"
                            properties = {
                              matchExpressions = {
                                description = "matchExpressions is a list of label selector requirements."
                                type        = "array"
                                items = {
                                  description = "A label selector requirement is a selector that contains values, a key, and an operator."
                                  type        = "object"
                                  properties = {
                                    key = {
                                      description = "key is the label key that the selector applies to."
                                      type        = "string"
                                    }
                                    operator = {
                                      description = "operator represents a key's relationship to a set of values."
                                      type        = "string"
                                    }
                                    values = {
                                      description = "values is an array of string values."
                                      type        = "array"
                                      items = {
                                        type = "string"
                                      }
                                    }
                                  }
                                  required = ["key", "operator"]
                                }
                              }
                              matchLabels = {
                                description = "matchLabels is a map of {key,value} pairs."
                                type        = "object"
                                additionalProperties = {
                                  type = "string"
                                }
                              }
                            }
                          }
                        }
                        serviceSelectors = {
                          description = "ServiceSelectors list of label selector to select service(s) for which ip pool can be used for ip allocation."
                          type        = "array"
                          items = {
                            description = "A label selector is a label query over a set of resources."
                            type        = "object"
                            properties = {
                              matchExpressions = {
                                description = "matchExpressions is a list of label selector requirements."
                                type        = "array"
                                items = {
                                  description = "A label selector requirement is a selector that contains values, a key, and an operator."
                                  type        = "object"
                                  properties = {
                                    key = {
                                      description = "key is the label key that the selector applies to."
                                      type        = "string"
                                    }
                                    operator = {
                                      description = "operator represents a key's relationship to a set of values."
                                      type        = "string"
                                    }
                                    values = {
                                      description = "values is an array of string values."
                                      type        = "array"
                                      items = {
                                        type = "string"
                                      }
                                    }
                                  }
                                  required = ["key", "operator"]
                                }
                              }
                              matchLabels = {
                                description = "matchLabels is a map of {key,value} pairs."
                                type        = "object"
                                additionalProperties = {
                                  type = "string"
                                }
                              }
                            }
                          }
                        }
                      }
                    }
                  }
                  required = ["addresses"]
                }
                status = {
                  description = "IPAddressPoolStatus defines the observed state of IPAddressPool."
                  type        = "object"
                }
              }
            }
          }
        }
      ]
    }
  }
}

# L2Advertisement CRD
resource "kubernetes_manifest" "l2advertisement_crd" {
  manifest = {
    apiVersion = "apiextensions.k8s.io/v1"
    kind       = "CustomResourceDefinition"
    
    metadata = {
      annotations = {
        "controller-gen.kubebuilder.io/version" = "v0.11.1"
      }
      name = "l2advertisements.metallb.io"
    }
    
    spec = {
      group = "metallb.io"
      names = {
        kind     = "L2Advertisement"
        listKind = "L2AdvertisementList"
        plural   = "l2advertisements"
        singular = "l2advertisement"
      }
      scope = "Namespaced"
      versions = [
        {
          name    = "v1beta1"
          served  = true
          storage = true
          schema = {
            openAPIV3Schema = {
              description = "L2Advertisement allows to advertise the LoadBalancer IPs provided by the selected pools via L2."
              type        = "object"
              properties = {
                apiVersion = {
                  description = "APIVersion defines the versioned schema of this representation of an object."
                  type        = "string"
                }
                kind = {
                  description = "Kind is a string value representing the REST resource this object represents."
                  type        = "string"
                }
                metadata = {
                  type = "object"
                }
                spec = {
                  description = "L2AdvertisementSpec defines the desired state of L2Advertisement."
                  type        = "object"
                  properties = {
                    ipAddressPools = {
                      description = "The list of IPAddressPools to advertise via this advertisement."
                      type        = "array"
                      items = {
                        type = "string"
                      }
                    }
                    ipAddressPoolSelectors = {
                      description = "A selector for the IPAddressPools which would get advertised via this advertisement."
                      type        = "array"
                      items = {
                        description = "A label selector is a label query over a set of resources."
                        type        = "object"
                        properties = {
                          matchExpressions = {
                            description = "matchExpressions is a list of label selector requirements."
                            type        = "array"
                            items = {
                              description = "A label selector requirement is a selector that contains values, a key, and an operator."
                              type        = "object"
                              properties = {
                                key = {
                                  description = "key is the label key that the selector applies to."
                                  type        = "string"
                                }
                                operator = {
                                  description = "operator represents a key's relationship to a set of values."
                                  type        = "string"
                                }
                                values = {
                                  description = "values is an array of string values."
                                  type        = "array"
                                  items = {
                                    type = "string"
                                  }
                                }
                              }
                              required = ["key", "operator"]
                            }
                          }
                          matchLabels = {
                            description = "matchLabels is a map of {key,value} pairs."
                            type        = "object"
                            additionalProperties = {
                              type = "string"
                            }
                          }
                        }
                      }
                    }
                    nodeSelectors = {
                      description = "NodeSelectors allows to limit the nodes to announce as next hops for the LoadBalancer IP."
                      type        = "array"
                      items = {
                        description = "A label selector is a label query over a set of resources."
                        type        = "object"
                        properties = {
                          matchExpressions = {
                            description = "matchExpressions is a list of label selector requirements."
                            type        = "array"
                            items = {
                              description = "A label selector requirement is a selector that contains values, a key, and an operator."
                              type        = "object"
                              properties = {
                                key = {
                                  description = "key is the label key that the selector applies to."
                                  type        = "string"
                                }
                                operator = {
                                  description = "operator represents a key's relationship to a set of values."
                                  type        = "string"
                                }
                                values = {
                                  description = "values is an array of string values."
                                  type        = "array"
                                  items = {
                                    type = "string"
                                  }
                                }
                              }
                              required = ["key", "operator"]
                            }
                          }
                          matchLabels = {
                            description = "matchLabels is a map of {key,value} pairs."
                            type        = "object"
                            additionalProperties = {
                              type = "string"
                            }
                          }
                        }
                      }
                    }
                    interfaces = {
                      description = "A list of interfaces to announce from."
                      type        = "array"
                      items = {
                        type = "string"
                      }
                    }
                  }
                }
                status = {
                  description = "L2AdvertisementStatus defines the observed state of L2Advertisement."
                  type        = "object"
                }
              }
            }
          }
        }
      ]
    }
  }
}

# Wait for CRDs to be ready and apply them via kubectl
resource "null_resource" "apply_crds" {
  depends_on = [
    kubernetes_deployment.controller,
    kubernetes_daemonset.speaker
  ]
  
  provisioner "local-exec" {
    command = <<-EOT
      # Wait for controller to be ready
      kubectl wait --for=condition=ready pod -l app=metallb,component=controller -n ${var.namespace} --timeout=300s
      
      # Apply CRDs if they don't exist
      if ! kubectl get crd ipaddresspools.metallb.io >/dev/null 2>&1; then
        kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.14.8/config/crd/bases/metallb.io_ipaddresspools.yaml
      fi
      
      if ! kubectl get crd l2advertisements.metallb.io >/dev/null 2>&1; then
        kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.14.8/config/crd/bases/metallb.io_l2advertisements.yaml
      fi
      
      # Wait a bit for CRDs to be ready
      sleep 10
    EOT
  }
  
  triggers = {
    controller = kubernetes_deployment.controller.metadata[0].uid
    speaker    = kubernetes_daemonset.speaker.metadata[0].uid
  }
}

# Wait for CRDs to be ready
resource "time_sleep" "wait_for_crds" {
  depends_on = [
    null_resource.apply_crds
  ]
  
  create_duration = "15s"
}

# Create IP Address Pool if configured
resource "kubernetes_manifest" "ip_address_pool" {
  count = length(var.ip_address_pools)
  
  manifest = {
    apiVersion = "metallb.io/v1beta1"
    kind       = "IPAddressPool"
    
    metadata = {
      name      = var.ip_address_pools[count.index].name
      namespace = var.namespace
    }
    
    spec = {
      addresses      = var.ip_address_pools[count.index].addresses
      autoAssign     = var.ip_address_pools[count.index].auto_assign
      avoidBuggyIPs  = var.ip_address_pools[count.index].avoid_buggy_ips
    }
  }
  
  depends_on = [
    time_sleep.wait_for_crds,
    kubernetes_namespace.metallb_system
  ]
}

# Create L2 Advertisement if configured  
resource "kubernetes_manifest" "l2_advertisement" {
  count = length(var.l2_advertisements)
  
  manifest = {
    apiVersion = "metallb.io/v1beta1"
    kind       = "L2Advertisement"
    
    metadata = {
      name      = var.l2_advertisements[count.index].name
      namespace = var.namespace
    }
    
    spec = {
      ipAddressPools = var.l2_advertisements[count.index].ip_address_pools
      interfaces     = var.l2_advertisements[count.index].interfaces
    }
  }
  
  depends_on = [
    kubernetes_manifest.l2advertisement_crd,
    time_sleep.wait_for_crds,
    kubernetes_manifest.ip_address_pool,
    kubernetes_namespace.metallb_system
  ]
}
