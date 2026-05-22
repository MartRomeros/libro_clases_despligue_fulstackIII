variable "aws_region" {
  description = "AWS region where infrastructure is deployed"
  type        = string
  default     = "us-east-1"
}

variable "public_ingress_cidr" {
  description = "Public CIDR allowed to access bastion/api-gw"
  type        = string
  default     = "0.0.0.0/0"
}

variable "ec2_key_name" {
  description = "AWS key pair name used by all EC2 instances"
  type        = string
  default     = "165387-vockey"
}

variable "ec2_instance_type" {
  description = "Instance type for all EC2 instances"
  type        = string
  default     = "t3.micro"
}

variable "ec2_root_volume_size" {
  description = "Root volume size in GiB for EC2 instances"
  type        = number
  default     = 20
}

variable "ec2_root_volume_type" {
  description = "Root volume type for EC2 instances"
  type        = string
  default     = "gp3"
}

variable "db_name" {
  description = "nombre de la base de datos"
  type        = string
}

variable "db_user" {
  description = "nombre de usuario"
  type        = string
}

variable "db_password" {
  description = "pass de la base de datos"
  type        = string
  sensitive   = true
}
