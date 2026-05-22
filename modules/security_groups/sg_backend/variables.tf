variable "vpc_id" {
  description = "Id de la vpc a asociar"
  type        = string
}

variable "public_sg_id" {
  description = "Security group ID publico autorizado para acceder al backend"
  type        = string
}
