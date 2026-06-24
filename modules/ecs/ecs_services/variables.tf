variable "name" {
  description = "Name for the ECS service"
  type        = string
}

variable "cluster_name" {
  description = "The name of the ECS cluster (required for autoscaling)."
  type        = string
}

variable "cpu" {
  description = "CPU units for the task"
  type        = number
}

variable "memory" {
  description = "Memory for the task in MiB"
  type        = number
}

variable "task_execution_role_arn" {
  description = "ARN of the IAM role that the ECS task will use for execution"
  type        = string
}

variable "container_image" {
  description = "Container image to use for the task"
  type        = string
}

variable "container_port" {
  description = "Port on which the container will listen"
  type        = number
}

variable "environment_variables" {
  description = "List of environment variables for the container."
  type = list(object({
    name  = string
    value = string
  }))
  default = []
}

variable "health_check_command" {
  description = "Command to run for the container health check (optional)."
  type        = list(string)
  default     = []
}

variable "aws_region" {
  description = "AWS region for CloudWatch logging."
  type        = string
  default     = "us-east-1"
}

variable "cluster_id" {
  description = "ID of the ECS cluster where the service will be deployed"
  type        = string
}

variable "desired_count" {
  description = "Number of desired tasks for the service"
  type        = number
}

variable "subnets" {
  description = "List of subnet IDs for the service's network configuration"
  type        = list(string)
}

variable "target_group_arn" {
  description = "ARN of the target group for load balancing (optional)"
  type        = string
  default     = ""
}

variable "service_registry_arn" {
  description = "ARN of the service registry for service discovery (optional)"
  type        = string
  default     = ""
}

variable "enable_autoscaling" {
  description = "Enable target tracking CPU autoscaling for this service."
  type        = bool
  default     = false
}

variable "security_group_id" {
  description = "ID of the security group to associate with the service"
  type        = string
}

variable "min_capacity" {
  description = "Minimum capacity for autoscaling."
  type        = number
  default     = 2
}

variable "max_capacity" {
  description = "Maximum capacity for autoscaling."
  type        = number
  default     = 10
}

variable "cpu_target_value" {
  description = "Target value for CPU utilization autoscaling policy."
  type        = number
  default     = 70
}
