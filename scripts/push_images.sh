#!/bin/bash

set -e

REGION="us-east-1"

echo "Obtieniendo urls de los ecr's"


echo "Preparando imagen ms autenticacion"
ECR_AUTH_URL=$(terraform output -json ecr_urls | jq -r '.ecr_colegio_auth')

echo $ECR_AUTH_URL

echo "Autenticando docker con aws"
aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ECR_AUTH_URL

echo "Construyendo imagen docker"
docker build -t ms-authenticaction-image ../ms_authentication

echo "Etiquetando imagen"
docker tag ms-authenticaction-image:latest ${ECR_AUTH_URL}:latest

echo "Subiendo el bff al ecr auth"
docker push ${ECR_AUTH_URL}:latest






echo "Preparando imagen ms asistencia"
ECR_ATTENDANCE_URL=$(terraform output -json ecr_urls | jq -r '.ecr_colegio_attendance')

echo $ECR_ATTENDANCE_URL

echo "Autenticando docker con aws"
aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ECR_ATTENDANCE_URL

echo "Construyendo imagen docker"
docker build -t ms-authenticaction-image ../ms_asistencia_conducta

echo "Etiquetando imagen"
docker tag ms-authenticaction-image:latest ${ECR_ATTENDANCE_URL}:latest

echo "Subiendo el bff al ecr asistencia"
docker push ${ECR_ATTENDANCE_URL}:latest







echo "Preparando imagen ms gestion"
ECR_GESTION_URL=$(terraform output -json ecr_urls | jq -r '.ecr_colegio_gestion')

echo $ECR_GESTION_URL

echo "Autenticando docker con aws"
aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ECR_GESTION_URL

echo "Construyendo imagen docker"
docker build -t ms-gestion-image ../BackGestion

echo "Etiquetando imagen"
docker tag ms-gestion-image:latest ${ECR_GESTION_URL}:latest

echo "Subiendo el bff al ecr gestion"
docker push ${ECR_GESTION_URL}:latest







echo "Preparando imagen ms comunicaciones"
ECR_COMUNICACIONES_URL=$(terraform output -json ecr_urls | jq -r '.ecr_colegio_comunicaciones')

echo $ECR_COMUNICACIONES_URL

echo "Autenticando docker con aws"
aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ECR_COMUNICACIONES_URL

echo "Construyendo imagen docker"
docker build -t ms-gestion-image ../MsMensajeria

echo "Etiquetando imagen"
docker tag ms-gestion-image:latest ${ECR_COMUNICACIONES_URL}:latest

echo "Subiendo el bff al ecr gestion"
docker push ${ECR_COMUNICACIONES_URL}:latest



echo "Imagenes subidas correctamente!"