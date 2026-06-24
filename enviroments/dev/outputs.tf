output "rds_endpoint" {
  value = aws_db_instance.colegio_db.endpoint
}

output "ec2_bastion_address" {
  value = module.ec2_instance.instance_id
}

output "api_gateway_base_url" {
  value = module.api_gateway.invoke_url
}
