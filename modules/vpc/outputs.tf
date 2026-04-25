output "vpc_id" {
  description = "The ID of the VPC"
  value       = module.vpc_colegio.vpc_id
}

output "private_subnets" {
  description = "List of IDs of private subnets"
  value       = module.vpc_colegio.private_subnets
}

output "public_subnets" {
  description = "List of IDs of public subnets"
  value       = module.vpc_colegio.public_subnets
}
