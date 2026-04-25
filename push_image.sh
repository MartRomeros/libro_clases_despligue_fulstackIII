#!/bin/zsh

# Script para subir la imagen del microservicio al ECR
# Uso: ./push_image.sh

set -e # Detener si hay errores

echo "🚀 Iniciando proceso de subida a ECR..."

# 1. Obtener la URL del repositorio desde Terraform
# Usamos -raw para obtener la cadena limpia
ECR_URL=$(terraform output -raw ecr_repository_url)

if [ -z "$ECR_URL" ]; then
    echo "❌ Error: No se pudo obtener la URL del ECR. ¿Ya ejecutaste 'terraform apply -target=module.ecr_auth'?"
    exit 1
fi

REGION="us-east-1"
echo "Found ECR URL: $ECR_URL"

# 2. Autenticar Docker con AWS ECR
echo "🔐 Autenticando Docker con AWS..."
aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ECR_URL

# 3. Construir la imagen Docker
# Asumimos que el Dockerfile está en la carpeta del microservicio. 
echo "📦 Construyendo imagen Docker..."
docker build -t ms-auth-image ../ms_authentication

# 4. Etiquetar la imagen para ECR
echo "🏷️ Etiquetando imagen..."
docker tag ms-auth-image:latest ${ECR_URL}:latest

# 5. Subir la imagen al repositorio
echo "📤 Subiendo imagen a ECR..."
docker push ${ECR_URL}:latest

# 6. Actualizar la función Lambda (solo si ya existe)
FUNCTION_NAME="ms-auth-function"
echo "🔍 Verificando existencia de la función Lambda: $FUNCTION_NAME..."

if aws lambda get-function --function-name "$FUNCTION_NAME" --region "$REGION" >/dev/null 2>&1; then
    echo "🔄 Actualizando la función Lambda para usar la nueva imagen..."
    aws lambda update-function-code --function-name "$FUNCTION_NAME" --image-uri "${ECR_URL}:latest" --region "$REGION"
    echo "✅ ¡Imagen subida y Lambda actualizada con éxito!"
else
    echo "ℹ️ La función Lambda '$FUNCTION_NAME' aún no existe. La imagen se ha subido correctamente y será utilizada en el próximo 'terraform apply'."
    echo "✅ ¡Proceso completado!"
fi
