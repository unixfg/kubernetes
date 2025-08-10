#!/bin/bash
# AKS Helper Functions
# Source this file to use the helper functions: source scripts/aks-helpers.sh

retry_with_backoff() {
    local max_attempts="${1:-3}"
    local delay="${2:-1}"
    local max_delay="${3:-8}"
    local name="${4:-command}"
    shift 4
    local cmd=("$@")
    local attempt=1
    while [ $attempt -le $max_attempts ]; do
        if [ $attempt -gt 1 ]; then
            echo "Retry $attempt/$max_attempts: $name (sleep ${delay}s)"
            sleep $delay
        fi
        if "${cmd[@]}"; then
            return 0
        fi
        if [ $attempt -eq $max_attempts ]; then
            echo "Failed after $max_attempts attempts: $name" >&2
            return 1
        fi
        delay=$(( delay * 2 ))
        [ $delay -gt $max_delay ] && delay=$max_delay
        delay=$(( delay + (RANDOM % 2) ))
        attempt=$(( attempt + 1 ))
    done
}

# Function to get AKS credentials using terraform outputs
# Usage: aks-creds [environment_path]
# Example: aks-creds environments/stage
aks-creds() {
    local env_path="${1:-$(pwd)}"
    
    # Change to the specified environment directory if provided
    if [[ "$1" != "" ]]; then
        if [[ ! -d "$env_path" ]]; then
    echo "Error: Directory '$env_path' not found"
            return 1
        fi
        pushd "$env_path" > /dev/null
    fi
    
    # Check if we're in a terraform directory
    if [[ ! -f "main.tf" ]]; then
        echo "Error: No main.tf found. Are you in a terraform environment directory?"
        if [[ "$1" != "" ]]; then
            popd > /dev/null
        fi
        return 1
    fi
    
    echo "Getting AKS credentials..."
    
    # Get resource group and cluster name from terraform outputs
    local rg_name
    local cluster_name
    
    rg_name=$(terraform output -raw resource_group_name 2>/dev/null)
    cluster_name=$(terraform output -raw cluster_name 2>/dev/null)
    
    if [[ -z "$rg_name" ]] || [[ -z "$cluster_name" ]]; then
        echo "❌ Error: Could not get resource group or cluster name from terraform outputs"
        echo "   Make sure you have run 'terraform apply' first"
        if [[ "$1" != "" ]]; then
            popd > /dev/null
        fi
        return 1
    fi
    
    echo "Resource Group: $rg_name"
    echo "Cluster Name: $cluster_name"
    
    # Execute the az aks get-credentials command
    retry_with_backoff 3 2 8 "az aks get-credentials" bash -c "timeout 15 az aks get-credentials --resource-group '$rg_name' --name '$cluster_name' --overwrite-existing"
    
    if [[ $? -eq 0 ]]; then
        echo "Successfully configured kubectl for cluster: $cluster_name"
        echo "You can now use kubectl commands."
    else
        echo "Failed to get AKS credentials"
        if [[ "$1" != "" ]]; then
            popd > /dev/null
        fi
        return 1
    fi
    
    # Return to original directory if we changed it
    if [[ "$1" != "" ]]; then
        popd > /dev/null
    fi
}

# Function to list available AKS clusters (bonus helper)
# Usage: aks-list
aks-list() {
    echo "Available AKS clusters:"
    retry_with_backoff 3 2 8 "az aks list" bash -c "timeout 15 az aks list --output table --query '[].{Name:name, ResourceGroup:resourceGroup, Location:location, Status:powerState.code}'"
}

# Function to show current kubectl context
# Usage: aks-context
aks-context() {
    echo "Current kubectl context:"
    if ! retry_with_backoff 3 2 6 "kubectl current-context" bash -c "timeout 10 kubectl config current-context >/dev/null 2>&1"; then
        echo "No current context set"
    else
        kubectl config current-context
    fi
    echo ""
    echo "Available contexts:"
    retry_with_backoff 3 2 6 "kubectl get-contexts" bash -c "timeout 10 kubectl config get-contexts >/dev/null 2>&1" && kubectl config get-contexts || true
}

# Function to show help
# Usage: aks-help
aks-help() {
    echo "AKS Helper Functions:"
    echo ""
    echo "  aks-creds [path]    - Get AKS credentials using terraform outputs"
    echo "                        Optionally specify environment path"
    echo "  aks-list           - List all available AKS clusters"
    echo "  aks-context        - Show current and available kubectl contexts"
    echo "  aks-help           - Show this help message"
    echo ""
    echo "Examples:"
    echo "  aks-creds                           # Use current directory"
    echo "  aks-creds environments/stage       # Use specific environment"
    echo "  aks-creds ../environments/prod     # Use relative path"
    echo ""
    echo "Tip: Source this file in your ~/.bashrc or ~/.zshrc for permanent access:"
    echo "   echo 'source ~/infrastructure/kubernetes/scripts/aks-helpers.sh' >> ~/.bashrc"
}

# Show help when script is sourced
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    echo "AKS helpers loaded. Run 'aks-help' for available functions."
fi