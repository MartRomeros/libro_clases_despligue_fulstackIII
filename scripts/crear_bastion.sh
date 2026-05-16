#!/bin/bash

set -e

REGION="us-east-1"
export AWS_DEFAULT_REGION="$REGION"

# 0. Manejo de llaves SSH (vockey)
echo "Configurando llaves SSH..."
if [ ! -f "vockey" ] || [ ! -f "vockey.pub" ]; then
    echo "Generando nueva llave SSH vockey..."
    ssh-keygen -t rsa -b 4096 -f vockey -N ""
fi
chmod 400 vockey


echo "Importando Key Pair 'vockey' a AWS..."
# Verificamos si existe; si existe, lo eliminamos para asegurar que coincida con nuestra llave local
if aws ec2 describe-key-pairs --key-names vockey --region "$REGION" >/dev/null 2>&1; then
    echo "El Key Pair 'vockey' ya existe. Re-importando para asegurar sincronización..."
    aws ec2 delete-key-pair --key-name vockey --region "$REGION"
fi

aws ec2 import-key-pair \
    --key-name "vockey" \
    --public-key-material fileb://vockey.pub \
    --region "$REGION"
echo "Key Pair 'vockey' importado exitosamente."

cd ../devops

# 1. Obtener valores de Terraform
echo "Obteniendo outputs de Terraform..."
SUBNET_ID=$(terraform output -raw public_subnet_id)
SG_ID=$(terraform output -raw bastion_sg_id)
RDS_ENDPOINT=$(terraform output -raw rds_endpoint)
AMI_ID=$(terraform output -raw ubuntu_ami_id)

# 2. Obtener credenciales de la DB desde terraform.tfvars
echo " Extrayendo credenciales de variables.tfvars..." #terraform.tfvars

DB_NAME=$(grep "db_name" terraform.tfvars | cut -d'=' -f2 | tr -d ' "')
DB_USER=$(grep "username" terraform.tfvars | cut -d'=' -f2 | tr -d ' "')
DB_PASS=$(grep "password" terraform.tfvars | cut -d'=' -f2 | tr -d ' "')

echo " Configuración:"
echo "   - Subnet: $SUBNET_ID"
echo "   - Security Group: $SG_ID"
echo "   - RDS Host: $RDS_ENDPOINT"
echo "   - AMI (Ubuntu): $AMI_ID"
echo "   - Región: $REGION"

# 3. Crear la instancia EC2
echo "Lanzando instancia EC2 (Ubuntu)..."
INSTANCE_ID=$(aws ec2 run-instances \
    --image-id "$AMI_ID" \
    --instance-type t2.micro \
    --subnet-id "$SUBNET_ID" \
    --security-group-ids "$SG_ID" \
    --associate-public-ip-address \
    --key-name vockey \
    --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=Bastion-Postgres-Colegio}]' \
    --query 'Instances[0].InstanceId' \
    --output text \
    --region "$REGION")

echo "Instancia creada: $INSTANCE_ID. Esperando a que esté en ejecución..."
aws ec2 wait instance-running --instance-ids "$INSTANCE_ID" --region "$REGION"

# Obtener IP Pública
PUBLIC_IP=$(aws ec2 describe-instances \
    --instance-ids "$INSTANCE_ID" \
    --query 'Reservations[0].Instances[0].PublicIpAddress' \
    --output text \
    --region "$REGION")

echo "Instancia lista! IP Pública: $PUBLIC_IP"


# 4. Preparar llave SSH (ya configurada en el paso 0)
echo "Verificando permisos de la llave vockey..."
chmod 400 vockey

# 5. Esperar a que SSH esté disponible (reintentos)
echo "Esperando a que el servicio SSH esté listo..."
MAX_RETRIES=10
RETRY_COUNT=0
until ssh -i vockey -o ConnectTimeout=5 -o StrictHostKeyChecking=no ubuntu@$PUBLIC_IP exit 2>/dev/null; do
    if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
        echo "Error: No se pudo conectar por SSH después de varios intentos."
        exit 1
    fi
    echo "   ...reintentando en 10 segundos ($RETRY_COUNT/$MAX_RETRIES)..."
    sleep 10
    RETRY_COUNT=$((RETRY_COUNT+1))
done

# 6. Instalar PostgreSQL Client y ejecutar script SQL
echo "Instalando postgresql-client en la instancia..."
ssh -i vockey -o StrictHostKeyChecking=no ubuntu@$PUBLIC_IP << EOF
    sudo apt-get update
    sudo apt-get install -y postgresql-client
EOF

echo "Copiando script.sql a la instancia..."
scp -i vockey -o StrictHostKeyChecking=no script.sql ubuntu@$PUBLIC_IP:/home/ubuntu/script.sql

echo "Poblando la base de datos RDS..."
ssh -i vockey -o StrictHostKeyChecking=no ubuntu@$PUBLIC_IP << EOF
    export PGPASSWORD='$DB_PASS'
    psql -h $RDS_ENDPOINT -U $DB_USER -d $DB_NAME -f /home/ubuntu/script.sql
    unset PGPASSWORD
EOF

echo "Proceso completado con éxito."
echo "Puedes acceder a la base de datos vía SSH: ssh -i vockey ubuntu@$PUBLIC_IP"
