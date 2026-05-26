#!/bin/bash
set -e

BUCKET_NAME="$1"

if [ -z "$BUCKET_NAME" ]; then
  echo "Uso: ./script.sh nombre-bucket"
  exit 1
fi

REGION="us-east-1"

echo "Creando bucket S3: $BUCKET_NAME"

aws s3api create-bucket \
  --bucket "$BUCKET_NAME" \
  --region "$REGION"

echo "Deshabilitando bloqueo público..."

aws s3api put-public-access-block \
  --bucket "$BUCKET_NAME" \
  --public-access-block-configuration \
  BlockPublicAcls=false,IgnorePublicAcls=false,BlockPublicPolicy=false,RestrictPublicBuckets=false

echo "Aplicando política pública..."

cat > bucket-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "PublicRead",
      "Effect": "Allow",
      "Principal": "*",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::$BUCKET_NAME/*"
    }
  ]
}
EOF

aws s3api put-bucket-policy \
  --bucket "$BUCKET_NAME" \
  --policy file://bucket-policy.json

echo "Configurando hosting estático..."

aws s3 website s3://$BUCKET_NAME \
  --index-document index.html \
  --error-document index.html

echo ""
echo "Bucket configurado correctamente"
echo ""
echo "URL:"
echo "http://$BUCKET_NAME.s3-website-us-east-1.amazonaws.com"