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

variable "key_name" {
  description = "AWS key pair name"
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
