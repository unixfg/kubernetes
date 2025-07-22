# Environment
environment = "dev"

# AKS
resource_group_location = "northcentralus"
node_count = 2
vm_size = "Standard_B2s"

# ArgoCD Configuration Source
git_repo_url = "https://github.com/unixfg/kubernetes-config.git"
