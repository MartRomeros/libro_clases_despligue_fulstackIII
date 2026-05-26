#!/bin/bash
set -e

RDS_ENDPOINT=$(terraform output -raw rds_endpoint)
RDS_HOST=$(echo "$RDS_ENDPOINT" | cut -d ':' -f1)

IP_BASTION=$(terraform output -json ec2_instance_addresses | jq -r '."ec2-bastion".public_ip')
IP_MS_GESTION=$(terraform output -json ec2_instance_addresses | jq -r '."ec2-ms-gestion".private_ip')

echo "RDS Host: $RDS_HOST"
echo "Bastion: $IP_BASTION"
echo "MS Gestion: $IP_MS_GESTION"

cd ~

chmod 400 165387-vockey.pem


ssh -o StrictHostKeyChecking=no \
  -i 165387-vockey.pem \
  ubuntu@"$IP_BASTION" <<EOF

set -e
chmod 400 /home/ubuntu/165387-vockey.pem

ssh -o StrictHostKeyChecking=no \
  -i /home/ubuntu/165387-vockey.pem \
  ubuntu@"$IP_MS_GESTION" <<REMOTE

set -e

sudo apt update
sudo apt install -y docker.io

sudo systemctl enable docker
sudo systemctl start docker


git --version
docker --version

rm -rf BackGestion
git clone https://github.com/AndresRomeroMadrid/BackGestion
cd BackGestion

cat > .env <<ENV
DB_URL=jdbc:postgresql://$RDS_HOST:5432/colegio
DB_USERNAME=postgres
DB_PASSWORD=secure-key
ENV

sudo docker build -t ms_gestion .

sudo docker rm -f ms_gestion || true

sudo docker run -d \
  --name ms_gestion \
  -p 8080:8080 \
  --env-file .env \
  ms_gestion

sudo docker ps
sudo docker logs ms_gestion

REMOTE
EOF