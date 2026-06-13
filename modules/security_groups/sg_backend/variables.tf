variable "vpc_id" {
  description = "Id de la vpc a asociar"
  type        = string
}

variable "alb_sg_id" {
  description = "SG del ALB para permitir tráfico de los microservicios"
  type        = string
}
