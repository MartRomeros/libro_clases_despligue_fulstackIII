output "public_subnet_id" {
  value = module.vpc_colegio.public_subnets[0]
}

output "bastion_sg_id" {
  value = module.sg_bastion.sg_bastion_id
}

output "rds_endpoint" {
  value = aws_db_instance.colegio_db.endpoint
}

output "ubuntu_ami_id" {
  value = data.aws_ami.ubuntu.id
}

output "ecr_urls" {
  value = {
    for key, repo in module.ecr_colegio :
    key => repo.ecr_url
  }
}

output "microservice_lambda_names" {
  description = "Function names for deployed microservice Lambdas"
  value = {
    auth           = module.ms_authentication_lambda.function_name
    attendance     = module.ms_attendance_lambda.function_name
    gestion        = module.ms_gestion_lambda.function_name
    comunicaciones = module.ms_comunicaciones_lambda.function_name
  }
}

output "microservice_lambda_invoke_arns" {
  description = "Invoke ARNs for deployed microservice Lambdas"
  value = {
    auth           = module.ms_authentication_lambda.invoke_arn
    attendance     = module.ms_attendance_lambda.invoke_arn
    gestion        = module.ms_gestion_lambda.invoke_arn
    comunicaciones = module.ms_comunicaciones_lambda.invoke_arn
  }
}

output "api_gateway_url" {
  value = module.api_gateway_http.api_endpoint
}

output "api_gateway_service_endpoints" {
  value = module.api_gateway_http.service_endpoints
}
