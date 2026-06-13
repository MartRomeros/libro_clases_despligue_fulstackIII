variable "name" {
  description = "HTTP API name"
  type        = string
}

variable "alb_listener_arn" {
  description = "ARN del listener del ALB interno (destino del VPC Link)"
  type        = string
}

variable "vpc_link_sg_id" {
  description = "ID del SG del VPC Link (creado externamente para evitar dependencia circular)"
  type        = string
}

variable "vpc_link_subnet_ids" {
  description = "Subnets privadas para el VPC Link"
  type        = list(string)
}

variable "stage_name" {
  description = "API Gateway stage name"
  type        = string
  default     = "$default"
}

variable "cors_allowed_origins" {
  description = "Allowed CORS origins"
  type        = list(string)
  default     = ["*"]
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
