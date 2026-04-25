output "backend_sg_id" {
  description = "The ID of the security group for backend"
  value       = module.security_groups_backend.security_group_id
}

output "database_sg_id" {
  description = "The ID of the security group for database"
  value       = module.security_groups_database.security_group_id
}

output "bastion_sg_id" {
  description = "The ID of the security group for bastion"
  value       = aws_security_group.sg_bastion.id
}
