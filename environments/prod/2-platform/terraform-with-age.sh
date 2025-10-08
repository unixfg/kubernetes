#!/bin/bash
# Terraform wrapper script for K3s SOPS with Age encryption
# Automatically exports Age key from file for Terraform variable injection

set -e

AGE_KEY_FILE="${AGE_KEY_FILE:-$HOME/infrastructure/age.key}"
AGE_KEY_ID="age15at06hfuzs3x4jqsrgjtcxujxaqetluv5mefxxyh0m4ge20ddywq37j2rf"

if [ ! -f "$AGE_KEY_FILE" ]; then
    echo "Error: Age key file not found at: $AGE_KEY_FILE"
    echo "Please generate an Age key first:"
    echo "  age-keygen -o ~/infrastructure/age.key"
    exit 1
fi

echo "Exporting Age key $AGE_KEY_ID..."

# Export Age private key content as Terraform variable
export TF_VAR_age_key_content="$(cat $AGE_KEY_FILE)"

# Export GitHub App private key if it exists
GITHUB_KEY_FILE="${GITHUB_KEY_FILE:-$HOME/infrastructure/github.key}"
if [ -f "$GITHUB_KEY_FILE" ]; then
    export TF_VAR_github_app_private_key="$(cat $GITHUB_KEY_FILE)"
fi

# Run terraform with provided arguments
echo "Running terraform $@"
terraform "$@"
