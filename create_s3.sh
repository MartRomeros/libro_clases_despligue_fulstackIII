#!/bin/zsh

# Script para crear el S3 de frontend en AWS Academy
# Evita los errores de Object Lock de Terraform

set -e

BUCKET_NAME="colegio-ohiggins-frontend-martin-v2026"
REGION="us-east-1"

echo "🪣 Creando bucket: $BUCKET_NAME..."
aws s3 mb s3://$BUCKET_NAME --region $REGION

echo "🌐 Configurando hosting estático..."
aws s3 website s3://$BUCKET_NAME/ --index-document index.html --error-document index.html

echo "🔓 Desactivando bloqueo de acceso público..."
# Nota: En algunas cuentas de Academy esto puede fallar, pero suele ser necesario para la política
aws s3api put-public-access-block \
    --bucket $BUCKET_NAME \
    --public-access-block-configuration "BlockPublicAcls=false,IgnorePublicAcls=false,BlockPublicPolicy=false,RestrictPublicBuckets=false"

echo "📜 Aplicando política de lectura pública..."
POLICY='{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "PublicReadGetObject",
            "Effect": "Allow",
            "Principal": "*",
            "Action": "s3:GetObject",
            "Resource": "arn:aws:s3:::VAR_BUCKET_NAME/*"
        }
    ]
}'

# Reemplazar el nombre del bucket en la política
FINAL_POLICY=$(echo $POLICY | sed "s/VAR_BUCKET_NAME/$BUCKET_NAME/g")
aws s3api put-bucket-policy --bucket $BUCKET_NAME --policy "$FINAL_POLICY"

echo "✅ S3 configurado con éxito."
echo "🔗 URL del sitio: http://$BUCKET_NAME.s3-website-$REGION.amazonaws.com"
