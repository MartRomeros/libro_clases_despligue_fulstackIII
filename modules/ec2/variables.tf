variable "name" {
  description = "Instance name"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "ami" {
  description = "AMI ID"
  type        = string
}

variable "iam_instance_profile" {
  description = "IAM instance profile name for SSM access"
  type        = string
}

variable "security_group_ids" {
  description = "Security groups for this instance"
  type        = list(string)
}

variable "subnet_id" {
  description = "Subnet ID where instance will be created"
  type        = string
}

variable "associate_public_ip_address" {
  description = "Whether to associate a public IP"
  type        = bool
  default     = false
}

variable "root_volume_size" {
  description = "Root EBS volume size in GiB"
  type        = number
  default     = 20
}

variable "root_volume_type" {
  description = "Root EBS volume type"
  type        = string
  default     = "gp3"
}

variable "ngrok_authtoken" {
  description = "Authtoken de ngrok para levantar el túnel HTTPS"
  type        = string
  sensitive   = true
}

variable "n8n_image" {
  description = "Imagen Docker de n8n a ejecutar"
  type        = string
  default     = "n8nio/n8n:latest"
}

variable "n8n_port" {
  description = "Puerto donde escucha n8n (host y contenedor) y al que apunta el túnel de ngrok"
  type        = number
  default     = 5678
}

variable "n8n_basic_auth_user" {
  description = "Usuario para la autenticación básica de n8n"
  type        = string
  sensitive   = true
}

variable "n8n_basic_auth_password" {
  description = "Password para la autenticación básica de n8n"
  type        = string
  sensitive   = true
}
