output "public_subnet_id" {
  value = module.vpc_colegio.public_subnets[0]
}

output "bastion_sg_id" {
  value = module.sg_bastion.sg_bastion_id
}

output "backend_sg_id" {
  value = module.sg_backend.sg_backend_id
}

output "rds_endpoint" {
  value = aws_db_instance.colegio_db.endpoint
}

output "ubuntu_ami_id" {
  value = data.aws_ami.ubuntu.id
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

output "api_gateway_base_url" {
  value = module.api_gateway.invoke_url
}

output "api_gateway_id" {
  value = module.api_gateway.api_id
}

output "nginx_origin_url" {
  value = "http://${module.ec2_instances["ec2-api-gw"].public_dns}"
}

output "ssh_commands" {
  value = {
    ec2_bastion = "ssh -i 165387-vockey.pem ubuntu@${module.ec2_instances["ec2-bastion"].public_ip}"
    ec2_api_gw  = "ssh -i 165387-vockey.pem ubuntu@${module.ec2_instances["ec2-api-gw"].public_ip}"
    ec2_ms_auth = "ssh -i 165387-vockey.pem -J ubuntu@${module.ec2_instances["ec2-bastion"].public_ip} ubuntu@${module.ec2_instances["ec2-ms-auth"].private_ip}"
    ec2_ms_asistencia = "ssh -i 165387-vockey.pem -J ubuntu@${module.ec2_instances["ec2-bastion"].public_ip} ubuntu@${module.ec2_instances["ec2-ms-asistencia"].private_ip}"
    ec2_ms_gestion = "ssh -i 165387-vockey.pem -J ubuntu@${module.ec2_instances["ec2-bastion"].public_ip} ubuntu@${module.ec2_instances["ec2-ms-gestion"].private_ip}"
    ec2_ms_comunicaciones = "ssh -i 165387-vockey.pem -J ubuntu@${module.ec2_instances["ec2-bastion"].public_ip} ubuntu@${module.ec2_instances["ec2-ms-comunicaciones"].private_ip}"
  }
}
