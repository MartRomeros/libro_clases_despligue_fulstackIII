variable "aws_region" {
  description = "AWS region where infrastructure is deployed"
  type        = string
  default     = "us-east-1"
}

variable "db_name" {
  description = "nombre de la base de datos"
  type        = string
}

variable "db_user" {
  description = "nombre de usuario"
  type        = string
}

variable "db_password" {
  description = "pass de la base de datos"
  type        = string
  sensitive   = true
}

variable "jwt_secret" {
  description = "JWT secret for authentication and attendance services"
  type        = string
  sensitive   = true
}

variable "resend_api_key" {
  description = "API key used by messaging service"
  type        = string
  sensitive   = true
}

variable "lambda_memory_size" {
  description = "Memory size for microservice Lambdas"
  type        = number
  default     = 512
}

variable "lambda_timeout" {
  description = "Timeout in seconds for microservice Lambdas"
  type        = number
  default     = 30
}

variable "api_stage_name" {
  description = "API Gateway HTTP stage name"
  type        = string
  default     = "prod"
}

variable "lambda_image_tag" {
  description = "Container image tag used by all microservice Lambdas"
  type        = string
  default     = "latest"
}
