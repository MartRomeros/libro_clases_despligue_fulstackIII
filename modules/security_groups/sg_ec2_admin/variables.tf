variable "vpc_id" {
  description = "Id de la VPC"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR de la VPC (usado para permitir resolución DNS interna)"
  type        = string
  default     = "10.0.0.0/16"
}
