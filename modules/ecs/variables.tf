variable "name_prefix" {
  description = "Prefix for naming resources"
  type        = string
}

variable "vpc_private_subnets" {
  description = "List of subnet IDs for the ECS services"
  type        = list(string)
}

variable "task_execution_role_arn" {
  description = "ARN of the IAM role for ECS task execution"
  type        = string
}

variable "alb_target_group_arns" {
  description = "Mapa de service key → ARN del target group del ALB (auth, asistencia, comunicaciones, gestion)"
  type        = map(string)
}

variable "security_group_id" {
  description = "ID of the security group for the ECS service"
  type        = string
}

variable "db_host" {
  description = "Endpoint del RDS PostgreSQL"
  type        = string
}

variable "db_name" {
  description = "Nombre de la base de datos"
  type        = string
  default     = "colegio"
}

variable "db_user" {
  description = "Usuario de la base de datos"
  type        = string
  default     = "postgres"
}

variable "db_password" {
  description = "Contraseña de la base de datos"
  type        = string
  sensitive   = true
}

variable "jwt_secret" {
  description = "Secret para firmar JWT en ms-auth"
  type        = string
  sensitive   = true
  default     = "default-jwt-secret"
}

variable "api_resend" {
  description = "API key de Resend para ms-comunicaciones"
  type        = string
  sensitive   = true
  default     = ""
}

variable "mail_host" {
  type = string
}

variable "mail_port" {
  type = string
}

variable "mail_user" {
  type = string
  sensitive = true
}

variable "mail_pass" {
  type = string
  sensitive = true
}

variable "sqs_queue_url" {
  type = string
}