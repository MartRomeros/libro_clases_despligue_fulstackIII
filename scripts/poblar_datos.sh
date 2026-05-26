#!/bin/bash

set -e

# Obtener valores del output de Terraform
RDS_ENDPOINT=$(terraform output -json | jq -r '.rds_endpoint.value')
RDS_HOST=$(echo "$RDS_ENDPOINT" | cut -d ':' -f1)
IP_BASTION=$(terraform output -json | jq -r '.ec2_instance_addresses.value["ec2-bastion"].public_ip')

cd ~

echo "RDS Endpoint: $RDS_ENDPOINT"
echo "RDS Host: $RDS_HOST"
echo "IP del Bastion: $IP_BASTION"

# Verificar conexión AWS
aws sts get-caller-identity

# Pasar script.sql al bastion
scp -o StrictHostKeyChecking=no \
    -i 165387-vockey.pem \
    script.sql ubuntu@"$IP_BASTION":~


scp -o StrictHostKeyChecking=no \
    -i 165387-vockey.pem \
    165387-vockey.pem ubuntu@"$IP_BASTION":~

# Conectarse al bastion, instalar psql y ejecutar script
ssh -o StrictHostKeyChecking=no \
    -i 165387-vockey.pem \
    ubuntu@"$IP_BASTION" <<EOF

set -e

sudo apt update
sudo apt install -y postgresql-client

export PGPASSWORD="secure-key"

psql -h "$RDS_HOST" -U postgres -d colegio < ~/script.sql

EOF