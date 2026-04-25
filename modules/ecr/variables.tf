variable "repository_name" {
  description = "Nombre del repositorio ECR"
  type        = string
}

variable "environment" {
  description = "Entorno del proyecto (ej: dev, prod)"
  type        = string
  default     = "dev"
}
