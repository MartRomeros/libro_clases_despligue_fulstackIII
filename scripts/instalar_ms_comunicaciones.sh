#!/bin/bash
set -e

RDS_ENDPOINT=$(terraform output -raw rds_endpoint)
RDS_HOST=$(echo "$RDS_ENDPOINT" | cut -d ':' -f1)

IP_BASTION=$(terraform output -json ec2_instance_addresses | jq -r '."ec2-bastion".public_ip')
IP_MS_COMUNICACIONES=$(terraform output -json ec2_instance_addresses | jq -r '."ec2-ms-comunicaciones".private_ip')

echo "RDS Host: $RDS_HOST"
echo "Bastion: $IP_BASTION"
echo "MS Comunicaciones: $IP_MS_COMUNICACIONES"

cd ~

chmod 400 165387-vockey.pem


ssh -o StrictHostKeyChecking=no \
  -i 165387-vockey.pem \
  ubuntu@"$IP_BASTION" <<EOF

set -e
chmod 400 /home/ubuntu/165387-vockey.pem

ssh -o StrictHostKeyChecking=no \
  -i /home/ubuntu/165387-vockey.pem \
  ubuntu@"$IP_MS_COMUNICACIONES" <<REMOTE

set -e

sudo apt update
sudo apt install -y docker.io

sudo systemctl enable docker
sudo systemctl start docker


git --version
docker --version

rm -rf MsMensajeria
git clone https://github.com/AndresRomeroMadrid/MsMensajeria
cd MsMensajeria

cat > .env <<ENV
PORT=3002
DB_USER=postgres
DB_PASSWORD=secure-key
DB_HOST=$RDS_HOST
DB_PORT=5432
DB_DATABASE=colegio
DB_SSL=true
UPLOAD_PATH=
RESEND_API_KEY=
RESEND_FROM_EMAIL=
TELEGRAM_BOT_TOKEN=
TELEGRAM_CHAT_ID=
ENV

sudo docker build -t ms_comunicaciones .

sudo docker rm -f ms_comunicaciones || true

sudo docker run -d \
  --name ms_comunicaciones \
  -p 3002:3002 \
  --env-file .env \
  ms_comunicaciones

sudo docker ps
sudo docker logs ms_comunicaciones

REMOTE
EOF