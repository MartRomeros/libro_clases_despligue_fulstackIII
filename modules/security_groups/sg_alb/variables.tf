variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "vpc_link_sg_id" {
  description = "ID del SG del VPC Link (API Gateway)"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR de la VPC (usado para el egress del ALB hacia el backend)"
  type        = string
  default     = "10.0.0.0/16"
}
