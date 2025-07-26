variable "namespace" {
  description = "Kubernetes namespace for MetalLB"
  type        = string
  default     = "metallb-system"
}

variable "metallb_version" {
  description = "MetalLB version (image tag)"
  type        = string
  default     = "v0.15.2"
}

variable "metallb_helm_chart_version" {
  description = "MetalLB Helm chart version"
  type        = string
  default     = "0.15.2"
}

variable "enable_bgp" {
  description = "Enable BGP mode (requires FRR)"
  type        = bool
  default     = false
}

variable "ip_address_pools" {
  description = "List of IP address pools for MetalLB to manage"
  type = list(object({
    name            = string
    addresses       = list(string)
    auto_assign     = optional(bool, true)
    avoid_buggy_ips = optional(bool, true)
  }))
  default = []
}

variable "l2_advertisements" {
  description = "List of L2 advertisement configurations"
  type = list(object({
    name             = string
    ip_address_pools = optional(list(string))
    node_selectors   = optional(list(map(string)))
    interfaces       = optional(list(string))
  }))
  default = []
}

variable "bgp_advertisements" {
  description = "List of BGP advertisement configurations (only used when enable_bgp=true)"
  type = list(object({
    name               = string
    ip_address_pools   = optional(list(string))
    aggregation_length = optional(number)
    localpref          = optional(number)
    communities        = optional(list(string))
    peers              = optional(list(string))
  }))
  default = []
}

variable "bgp_peers" {
  description = "List of BGP peer configurations (only used when enable_bgp=true)"
  type = list(object({
    name           = string
    my_asn         = number
    peer_asn       = number
    peer_address   = string
    peer_port      = optional(number)
    source_address = optional(string)
    node_selectors = optional(list(map(string)))
    password       = optional(string)
    hold_time      = optional(string)
    keepalive_time = optional(string)
    router_id      = optional(string)
  }))
  default = []
}

variable "controller_resources" {
  description = "Resource limits and requests for MetalLB controller"
  type = object({
    limits = optional(object({
      cpu    = optional(string, "100m")
      memory = optional(string, "100Mi")
    }))
    requests = optional(object({
      cpu    = optional(string, "100m")
      memory = optional(string, "100Mi")
    }))
  })
  default = {}
}

variable "speaker_resources" {
  description = "Resource limits and requests for MetalLB speaker"
  type = object({
    limits = optional(object({
      cpu    = optional(string, "100m")
      memory = optional(string, "100Mi")
    }))
    requests = optional(object({
      cpu    = optional(string, "100m")
      memory = optional(string, "100Mi")
    }))
  })
  default = {}
}

variable "controller_node_selector" {
  description = "Node selector for MetalLB controller"
  type        = map(string)
  default     = {}
}

variable "speaker_node_selector" {
  description = "Node selector for MetalLB speaker pods"
  type        = map(string)
  default     = {}
}

variable "controller_tolerations" {
  description = "Tolerations for MetalLB controller"
  type = list(object({
    key               = optional(string)
    operator          = optional(string, "Equal")
    value             = optional(string)
    effect            = optional(string)
    toleration_seconds = optional(number)
  }))
  default = []
}

variable "speaker_tolerations" {
  description = "Tolerations for MetalLB speaker pods"
  type = list(object({
    key               = optional(string)
    operator          = optional(string, "Equal")
    value             = optional(string)
    effect            = optional(string)
    toleration_seconds = optional(number)
  }))
  default = []
}

variable "enable_prometheus_metrics" {
  description = "Enable Prometheus metrics collection"
  type        = bool
  default     = false
}

variable "prometheus_service_account" {
  description = "Service account used by Prometheus for metrics scraping"
  type        = string
  default     = ""
}
      cpu    = string
      memory = string
    })
    requests = object({
      cpu    = string
      memory = string
    })
  })
  default = {
    limits = {
      cpu    = "100m"
      memory = "100Mi"
    }
    requests = {
      cpu    = "100m"
      memory = "100Mi"
    }
  }
}

variable "speaker_resources" {
  description = "Resource limits and requests for MetalLB speaker"
  type = object({
    limits = object({
      cpu    = string
      memory = string
    })
    requests = object({
      cpu    = string
      memory = string
    })
  })
  default = {
    limits = {
      cpu    = "100m"
      memory = "100Mi"
    }
    requests = {
      cpu    = "100m"
      memory = "100Mi"
    }
  }
}

variable "ip_address_pools" {
  description = "List of IP address pools for MetalLB"
  type = list(object({
    name            = string
    addresses       = list(string)
    auto_assign     = optional(bool, true)
    avoid_buggy_ips = optional(bool, false)
  }))
  default = []
}

variable "l2_advertisements" {
  description = "List of L2 advertisements for MetalLB"
  type = list(object({
    name             = string
    ip_address_pools = list(string)
    interfaces       = optional(list(string), [])
  }))
  default = []
}

variable "enable_bgp" {
  description = "Enable BGP mode (requires additional BGP configuration)"
  type        = bool
  default     = false
}

variable "bgp_peers" {
  description = "List of BGP peers when BGP mode is enabled"
  type = list(object({
    name         = string
    peer_address = string
    peer_asn     = number
    my_asn       = number
    router_id    = optional(string)
    password     = optional(string)
    hold_time    = optional(string, "90s")
    keepalive_time = optional(string, "30s")
    node_selectors = optional(list(object({
      match_labels = optional(map(string))
      match_expressions = optional(list(object({
        key      = string
        operator = string
        values   = list(string)
      })))
    })), [])
  }))
  default = []
}

variable "bgp_advertisements" {
  description = "List of BGP advertisements when BGP mode is enabled"
  type = list(object({
    name                    = string
    ip_address_pools       = list(string)
    aggregation_length     = optional(number)
    aggregation_length_v6  = optional(number)
    local_pref             = optional(number)
    communities            = optional(list(string), [])
    peers                  = optional(list(string), [])
  }))
  default = []
}

variable "communities" {
  description = "List of BGP communities"
  type = list(object({
    name  = string
    value = string
  }))
  default = []
}

variable "bfd_profiles" {
  description = "List of BFD profiles for BGP sessions"
  type = list(object({
    name                = string
    receive_interval    = optional(number, 300)
    transmit_interval   = optional(number, 300)
    detect_multiplier   = optional(number, 3)
    echo_interval       = optional(number, 50)
    echo_mode          = optional(bool, false)
    passive_mode       = optional(bool, false)
    minimum_ttl        = optional(number, 254)
  }))
  default = []
}

variable "enable_prometheus_monitoring" {
  description = "Enable Prometheus monitoring annotations"
  type        = bool
  default     = true
}

variable "webhook_cert_validity_hours" {
  description = "Validity period for webhook TLS certificate in hours"
  type        = number
  default     = 8760 # 1 year
}

variable "memberlist_secret_key_length" {
  description = "Length of the memberlist secret key"
  type        = number
  default     = 128
}

variable "enable_speaker_frr_k8s" {
  description = "Enable FRR-K8s integration for advanced BGP features"
  type        = bool
  default     = false
}

variable "speaker_frr_image" {
  description = "FRR image for speaker when FRR-K8s is enabled"
  type        = string
  default     = "quay.io/frrouting/frr:8.5.1"
}

variable "enable_layer2_mode" {
  description = "Enable Layer 2 mode (ARP/NDP)"
  type        = bool
  default     = true
}

variable "layer2_interfaces" {
  description = "Specific interfaces to use for Layer 2 announcements"
  type        = list(string)
  default     = []
}

variable "metallb_config_map_data" {
  description = "Additional configuration data for MetalLB config map (legacy config format support)"
  type        = map(string)
  default     = {}
}

variable "pod_security_policy_enabled" {
  description = "Enable Pod Security Policies for MetalLB"
  type        = bool
  default     = false
}

variable "network_policy_enabled" {
  description = "Enable NetworkPolicy for MetalLB namespace"
  type        = bool
  default     = false
}

variable "priority_class_name" {
  description = "Priority class name for MetalLB pods"
  type        = string
  default     = ""
}

variable "image_pull_secrets" {
  description = "Image pull secrets for MetalLB pods"
  type        = list(string)
  default     = []
}

variable "extra_labels" {
  description = "Extra labels to apply to all MetalLB resources"
  type        = map(string)
  default     = {}
}

variable "extra_annotations" {
  description = "Extra annotations to apply to all MetalLB resources"
  type        = map(string)
  default     = {}
}

variable "exclude_load_balancer_class" {
  description = "Exclude specific LoadBalancer class from MetalLB management"
  type        = list(string)
  default     = []
}

variable "load_balancer_class" {
  description = "LoadBalancer class that MetalLB should handle"
  type        = string
  default     = "metallb.universe.tf/metallb"
}

variable "ignore_excluded_lb" {
  description = "Ignore LoadBalancer services with excluded annotations"
  type        = bool
  default     = true
}
