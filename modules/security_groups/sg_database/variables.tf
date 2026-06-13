variable "vpc_id" {
  description = "Id de la vpc para asociarlo"
  type        = string
}

variable "sg_backend_id" {
  description = "Id del grupo de seguridad backend para permitir acceso al RDS"
  type        = string
}
