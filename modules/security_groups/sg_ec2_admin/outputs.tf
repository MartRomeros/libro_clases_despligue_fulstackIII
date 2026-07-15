output "sg_ec2_admin_id" {
  description = "Id del grupo de seguridad de la EC2 de administración"
  value       = module.sg_ec2_admin.security_group_id
}
