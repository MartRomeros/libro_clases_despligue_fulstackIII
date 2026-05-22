variable "vpc_id" {
  description = "Id de la vpc a asociar"
  type        = string

}

variable "public_ingress_cidr" {
  description = "CIDR permitido para trafico publico"
  type        = string
  default     = "0.0.0.0/0"
}

