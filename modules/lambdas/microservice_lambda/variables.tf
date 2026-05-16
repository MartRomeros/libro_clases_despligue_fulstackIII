variable "function_name" {
  description = "Lambda function name"
  type        = string
}

variable "image_uri" {
  description = "Container image URI stored in ECR"
  type        = string
}

variable "role_arn" {
  description = "IAM role ARN assumed by the Lambda function"
  type        = string
}

variable "private_subnets" {
  description = "Private subnet IDs where the Lambda is attached"
  type        = list(string)
}

variable "security_group_id" {
  description = "Security group attached to the Lambda ENIs"
  type        = string
}

variable "environment_variables" {
  description = "Environment variables injected into the Lambda"
  type        = map(string)
  default     = {}
}

variable "memory_size" {
  description = "Lambda memory size in MB"
  type        = number
  default     = 512
}

variable "timeout" {
  description = "Lambda timeout in seconds"
  type        = number
  default     = 30
}
