#!/bin/bash
# Regenerates inventory/hosts.ini from the current Terraform state, so you
# never have to copy the instance's IP by hand after `terraform apply`.
set -euo pipefail

cd "$(dirname "$0")"

IP=$(terraform -chdir=../terraform output -raw instance_public_ip)

echo "[app]" > inventory/hosts.ini
echo "$IP" >> inventory/hosts.ini

echo "inventory/hosts.ini -> $IP"
