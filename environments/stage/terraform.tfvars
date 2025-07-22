# Stage Environment Configuration
# Copy this to terraform.tfvars and customize

# Environment
environment = "stage"

# AKS
resource_group_location = "northcentralus"
node_count = 3
vm_size = "Standard_B2ms"