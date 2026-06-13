output "sg_alb_id" {
  description = "ID del security group del ALB"
  value       = module.sg_alb.security_group_id
}
