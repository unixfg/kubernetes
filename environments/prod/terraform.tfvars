# Production Environment Configuration
# Copy this to terraform.tfvars and customize

# Environment
environment = "prod"

# AKS
resource_group_location = "eastus"
node_count = 5
vm_size = "Standard_D2s_v3"