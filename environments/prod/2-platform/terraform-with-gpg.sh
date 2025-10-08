#!/bin/bash
# Helper script to run Terraform with GPG keys for sops-secrets-operator
# Usage: ./terraform-with-gpg.sh plan
#        ./terraform-with-gpg.sh apply main.tfplan

set -euo pipefail

GPG_KEY_ID="EB825EA30B5CD2224E1943327E47132896E84B26"

echo "Exporting GPG key $GPG_KEY_ID..."

# Export and encode keys
export TF_VAR_gpg_private_key_content="$(gpg --export-secret-keys --armor $GPG_KEY_ID | base64 -w0)"
export TF_VAR_gpg_public_key_content="$(gpg --export --armor $GPG_KEY_ID | base64 -w0)"

echo "Running terraform $@"
terraform "$@"
