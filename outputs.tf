output "rds_endpoint" {
  value = aws_db_instance.colegio_db.endpoint
}

output "ec2_instance_addresses" {
  value = {
    for name, instance in module.ec2_instances :
    name => {
      instance_id = instance.instance_id
      public_ip   = instance.public_ip
      private_ip  = instance.private_ip
      public_dns  = instance.public_dns
    }
  }
}

output "alb_dns_name" {
  value       = module.alb.alb_dns_name
  description = "DNS interno del ALB (no accesible desde Internet)"
}

output "api_gateway_base_url" {
  value = module.api_gateway.invoke_url
}
