variable "name" {
  description = "ALB name"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "subnets" {
  description = "Private subnet IDs for the internal ALB"
  type        = list(string)
}

variable "security_group_ids" {
  description = "Security group IDs attached to the ALB"
  type        = list(string)
}

variable "services" {
  description = "Map of service key to instance_id and port for target group creation"
  type = map(object({
    instance_id = string
    port        = number
  }))
}

variable "routes" {
  description = "Listener rules ordered by priority (lower number = higher priority, max 5 path_patterns per rule)"
  type = list(object({
    priority      = number
    service_key   = string
    path_patterns = list(string)
  }))
}
