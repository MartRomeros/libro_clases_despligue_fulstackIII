output "instance_id" {
  value = module.ec2.id
}

output "public_ip" {
  value = module.ec2.public_ip
}

output "private_ip" {
  value = module.ec2.private_ip
}

output "public_dns" {
  value = module.ec2.public_dns
}

output "ssm_session_command" {
  description = "Comando para abrir una sesión SSM hacia la instancia (no hay acceso SSH)"
  value       = "aws ssm start-session --target ${module.ec2.id}"
}

output "ngrok_url_check_command" {
  description = "Comando a ejecutar DENTRO de la sesión SSM para obtener la URL pública actual del túnel de ngrok"
  value       = "curl -s http://127.0.0.1:4040/api/tunnels | jq -r '.tunnels[0].public_url'"
}
