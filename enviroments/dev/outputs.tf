output "rds_endpoint" {
  value = aws_db_instance.colegio_db.endpoint
}

output "ec2_bastion_address" {
  value = module.ec2_instance.instance_id
}

output "ec2_bastion_ssm_session_command" {
  description = "Comando para conectarse a la EC2 vía SSM (no hay SSH)"
  value       = module.ec2_instance.ssm_session_command
}

output "ec2_bastion_ngrok_url_check_command" {
  description = "Comando a correr dentro de la sesión SSM para ver la URL pública actual de n8n"
  value       = module.ec2_instance.ngrok_url_check_command
}

output "api_gateway_base_url" {
  value = module.api_gateway.invoke_url
}
