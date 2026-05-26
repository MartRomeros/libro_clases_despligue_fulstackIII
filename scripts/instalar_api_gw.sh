#!/bin/bash
set -e

IP_BASTION=$(terraform output -json ec2_instance_addresses | jq -r '."ec2-bastion".public_ip')
IP_API_GW=$(terraform output -json ec2_instance_addresses | jq -r '."ec2-api-gw".private_ip')
IP_MS_AUTH=$(terraform output -json ec2_instance_addresses | jq -r '."ec2-ms-auth".private_ip')
IP_MS_ASISTENCIA=$(terraform output -json ec2_instance_addresses | jq -r '."ec2-ms-asistencia".private_ip')
IP_MS_COMUNICACIONES=$(terraform output -json ec2_instance_addresses | jq -r '."ec2-ms-comunicaciones".private_ip')
IP_MS_GESTION=$(terraform output -json ec2_instance_addresses | jq -r '."ec2-ms-gestion".private_ip')

echo "RDS Host: $RDS_HOST"
echo "Bastion: $IP_BASTION"
echo "API GW: $IP_API_GW"
echo "MS Auth: $IP_MS_AUTH"
echo "MS Asistencia: $IP_MS_ASISTENCIA"
echo "MS Comunicaciones: $IP_MS_COMUNICACIONES"
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
  ubuntu@"$IP_API_GW" <<REMOTE

set -e

sudo apt update
sudo apt install -y docker.io

sudo systemctl enable docker
sudo systemctl start docker


git --version
docker --version

rm -rf Api_GW
git clone https://github.com/MartRomeros/Api_GW
cd Api_GW

cat > default.conf <<ENV
#si estas desarrollando un ms debes dejarlo en localhost
#si estas ejecutando el contenedor del ms colocar el nombre del contenedor y su misma red

server {
    listen 80;

    location /api/auth/ {
        proxy_pass http://$IP_MS_AUTH:3000;
        include /etc/nginx/conf.d/proxy-headers.conf;
    }

    location = /api/teachers/me/dashboard {
        proxy_pass http://$IP_MS_AUTH:3000;
        include /etc/nginx/conf.d/proxy-headers.conf;
    }

    location = /api/students/me/dashboard {
        proxy_pass http://$IP_MS_AUTH:3000;
        include /etc/nginx/conf.d/proxy-headers.conf;
    }

    location = /api/admin/me/dashboard {
        proxy_pass http://$IP_MS_AUTH:3000;
        include /etc/nginx/conf.d/proxy-headers.conf;
    }

    #MS ASISTENCIA

    location /api/anotaciones {
        proxy_pass http://$IP_MS_ASISTENCIA:3001;
        include /etc/nginx/conf.d/proxy-headers.conf;
    }

    location /api/asistencia {
        proxy_pass http://$IP_MS_ASISTENCIA:3001;
        include /etc/nginx/conf.d/proxy-headers.conf;
    }

    location = /api/docentes/cursos {
        proxy_pass http://$IP_MS_ASISTENCIA:3001;
        include /etc/nginx/conf.d/proxy-headers.conf;
    }

    location ~ ^/api/cursos/[^/]+/alumnos$ {
        proxy_pass http://$IP_MS_ASISTENCIA:3001;
        include /etc/nginx/conf.d/proxy-headers.conf;
    }

    # MS COMUNICACIONES

    location /api/mensajes {
        proxy_pass http://$IP_MS_COMUNICACIONES:3002;
        include /etc/nginx/conf.d/proxy-headers.conf;
    }

    # MS GESTION

    location /api/academico {
        proxy_pass http://$IP_MS_GESTION:8080;
        include /etc/nginx/conf.d/proxy-headers.conf;
    }

    location /api/docentes {
        proxy_pass http://$IP_MS_GESTION:8080;
        include /etc/nginx/conf.d/proxy-headers.conf;
    }

    location /api/estudiantes {
        proxy_pass http://$IP_MS_GESTION:8080;
        include /etc/nginx/conf.d/proxy-headers.conf;
    }

    location /api/evaluaciones {
        proxy_pass http://$IP_MS_GESTION:8080;
        include /etc/nginx/conf.d/proxy-headers.conf;
    }

    location /api/notas {
        proxy_pass http://$IP_MS_GESTION:8080;
        include /etc/nginx/conf.d/proxy-headers.conf;
    }

    location /api/usuarios {
        proxy_pass http://$IP_MS_GESTION:8080;
        include /etc/nginx/conf.d/proxy-headers.conf;
    }
}
ENV

sudo docker build -t api_gw .

sudo docker rm -f api_gw || true

sudo docker run -d \
  --name api_gw \
  -p 80:80 \
  api_gw

sudo docker ps
sudo docker logs api_gw

REMOTE
EOF