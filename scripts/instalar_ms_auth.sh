#!/bin/bash
set -e

RDS_ENDPOINT=$(terraform output -raw rds_endpoint)
RDS_HOST=$(echo "$RDS_ENDPOINT" | cut -d ':' -f1)

IP_BASTION=$(terraform output -json ec2_instance_addresses | jq -r '."ec2-bastion".public_ip')
IP_MS_AUTH=$(terraform output -json ec2_instance_addresses | jq -r '."ec2-ms-auth".private_ip')

echo "RDS Host: $RDS_HOST"
echo "Bastion: $IP_BASTION"
echo "MS Auth: $IP_MS_AUTH"

cd ~

chmod 400 165387-vockey.pem


ssh -o StrictHostKeyChecking=no \
  -i 165387-vockey.pem \
  ubuntu@"$IP_BASTION" <<EOF

set -e
chmod 400 /home/ubuntu/165387-vockey.pem

ssh -o StrictHostKeyChecking=no \
  -i /home/ubuntu/165387-vockey.pem \
  ubuntu@"$IP_MS_AUTH" <<REMOTE

set -e

sudo apt update
sudo apt install -y docker.io

sudo systemctl enable docker
sudo systemctl start docker


git --version
docker --version

rm -rf MS_Auth
git clone https://github.com/MartRomeros/MS_Auth
cd MS_Auth

cat > .env <<ENV
PORT=3000
JWT_SECRET=default-secret
SALT_ROUNDS=12
DB_USER=postgres
DB_PASSWORD=secure-key
DB_HOST=$RDS_HOST
DB_PORT=5432
DB_DATABASE=colegio
DB_SSL=true
ENV

sudo docker build -t ms_auth .

sudo docker rm -f ms_auth || true

sudo docker run -d \
  --name ms_auth \
  -p 3000:3000 \
  --env-file .env \
  ms_auth

sudo docker ps
sudo docker logs ms_auth

curl -X POST http://localhost:3000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@colegio","password":"123"}'

REMOTE
EOF