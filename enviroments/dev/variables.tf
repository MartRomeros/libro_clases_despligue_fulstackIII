variable "aws_region" {
  description = "AWS region where infrastructure is deployed"
  type        = string
  default     = "us-east-1"
}

variable "public_ingress_cidr" {
  description = "Public CIDR allowed to access bastion/api-gw"
  type        = string
  default     = "0.0.0.0/0"
}

variable "ec2_instance_type" {
  description = "Instance type for all EC2 instances"
  type        = string
  default     = "t3.micro"
}

variable "ec2_root_volume_size" {
  description = "Root volume size in GiB for EC2 instances"
  type        = number
  default     = 20
}

variable "ec2_root_volume_type" {
  description = "Root volume type for EC2 instances"
  type        = string
  default     = "gp3"
}

variable "db_name" {
  description = "nombre de la base de datos"
  type        = string
  default     = "colegio"
}

variable "db_user" {
  description = "nombre de usuario"
  type        = string
  default     = "postgres"
}

variable "db_password" {
  description = "pass de la base de datos"
  type        = string
  default     = "secure-key"
  sensitive   = true
}

variable "project_name" {
  description = "Nombre del proyecto para etiquetado"
  type        = string
}

variable "owner_name" {
  description = "Nombre del propietario para etiquetado"
  type        = string
}

variable "environment" {
  description = "Entorno de despliegue (e.g., dev, staging, prod)"
  type        = string
}

variable "mail_host" {
  type = string
}

variable "mail_pass" {
  type = string
}

variable "mail_user" {
  type = string
}

variable "mail_port" {
  type = number
}

variable "jwt_secret" {
  description = "Secret para firmar JWT en ms-auth"
  type        = string
  sensitive   = true
  default     = "default-jwt-secret"
}

variable "ngrok_authtoken" {
  description = "Authtoken de ngrok para el túnel HTTPS de n8n en la EC2 de administración"
  type        = string
  sensitive   = true
}

variable "n8n_basic_auth_user" {
  description = "Usuario de autenticación básica para n8n"
  type        = string
  sensitive   = true
}

variable "n8n_basic_auth_password" {
  description = "Password de autenticación básica para n8n"
  type        = string
  sensitive   = true
}
