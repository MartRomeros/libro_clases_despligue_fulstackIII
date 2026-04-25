variable "db_name" {
  description = "Nombre de la BD"
  type        = string
  sensitive   = true
}


variable "username" {
  description = "usuario de la BD"
  type        = string
  sensitive   = true
}

variable "password" {
  description = "pass de la BD "
  type        = string
  sensitive   = true
}

variable "jwt_secret" {
  description = "Secret key for JWT"
  type        = string
  sensitive   = true
}

