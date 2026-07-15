variable "vpc_id" {
  description = "Id de la vpc para asociarlo"
  type        = string
}

variable "sg_backend_id" {
  description = "Id del grupo de seguridad backend para permitir acceso al RDS"
  type        = string
}

variable "sg_ec2_admin_id" {
  description = "Id del grupo de seguridad de la EC2 de administración para permitir acceso al RDS"
  type        = string
}
