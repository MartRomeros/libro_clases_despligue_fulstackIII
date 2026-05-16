output "sg_bastion_id" {
  description = "Id del grupo de seguridad "
  value       = module.sg_bastion.security_group_id
}