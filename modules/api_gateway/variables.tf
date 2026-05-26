variable "name" {
  description = "HTTP API name"
  type        = string
}

variable "nginx_base_url" {
  description = "Base HTTP URL for nginx origin, for example http://ec2-x-x-x-x.compute-1.amazonaws.com"
  type        = string

  validation {
    condition     = can(regex("^http://", var.nginx_base_url))
    error_message = "nginx_base_url must start with http://"
  }
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
