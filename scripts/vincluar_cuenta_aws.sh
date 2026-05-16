#!/bin/bash

# script para configurar el perfil de aws academy en la maquina local

set -e

echo "Configurando AWS Academy"
echo " "
echo "Ingresa tu aws_access_key_id"
read aws_access_key_id
echo " "
echo "Ingresa tu aws_secret_access_key"
read aws_secret_access_key
echo " "
echo "Ingresa tu aws_session_token"
read aws_session_token

cd ~/.aws/

echo "[academy]" > credentials
echo "aws_access_key_id = "$aws_access_key_id >> credentials
echo "aws_secret_access_key = "$aws_secret_access_key >> credentials
echo "aws_session_token = "$aws_session_token >> credentials
#aws iam get-role --role-name LabRole --query 'Role.Arn' --output text
echo " "

echo "Perfil cargado correctamente !"








