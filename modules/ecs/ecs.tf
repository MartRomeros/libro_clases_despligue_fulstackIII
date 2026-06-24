locals {
  cpu                = 256
  memory             = 512
  desired_count      = 2
  enable_autoscaling = true
  min_capacity       = 2
  max_capacity       = 10
  cpu_target_value   = 70
}


resource "aws_ecs_cluster" "this" {
  name = "${var.name_prefix}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

module "ms_auth" {
  source = "./ecs_services"

  name                    = "${var.name_prefix}-ms-auth"
  cluster_id              = aws_ecs_cluster.this.id
  cluster_name            = aws_ecs_cluster.this.name
  subnets                 = var.vpc_private_subnets
  task_execution_role_arn = var.task_execution_role_arn

  cpu             = local.cpu
  memory          = local.memory
  container_image = "martromeros/ms-auth:latest"
  container_port  = 3000
  desired_count   = local.desired_count

  environment_variables = [
    { name = "PORT", value = "3000" },
    { name = "JWT_SECRET", value = var.jwt_secret },
    { name = "SALT_ROUNDS", value = "12" },
    { name = "DB_USER", value = var.db_user },
    { name = "DB_PASSWORD", value = var.db_password },
    { name = "DB_HOST", value = var.db_host },
    { name = "DB_PORT", value = "5432" },
    { name = "DB_DATABASE", value = var.db_name },
    { name = "DB_SSL", value = "true" }
  ]

  target_group_arn   = var.alb_target_group_arns["auth"]
  security_group_id  = var.security_group_id
  enable_autoscaling = local.enable_autoscaling
  min_capacity       = local.min_capacity
  max_capacity       = local.max_capacity
  cpu_target_value   = local.cpu_target_value



}

module "ms_asistencia" {
  source = "./ecs_services"

  name                    = "${var.name_prefix}-ms-asistencia"
  cluster_id              = aws_ecs_cluster.this.id
  cluster_name            = aws_ecs_cluster.this.name
  subnets                 = var.vpc_private_subnets
  task_execution_role_arn = var.task_execution_role_arn

  cpu             = local.cpu
  memory          = local.memory
  container_image = "martromeros/ms-asistencia:latest"
  container_port  = 3001
  desired_count   = local.desired_count

  environment_variables = [
    { name = "PORT", value = "3001" },
    { name = "DB_USER", value = var.db_user },
    { name = "DB_PASSWORD", value = var.db_password },
    { name = "DB_HOST", value = var.db_host },
    { name = "DB_PORT", value = "5432" },
    { name = "DB_DATABASE", value = var.db_name },
    { name = "DB_SSL", value = "true" }
  ]

  target_group_arn   = var.alb_target_group_arns["asistencia"]
  security_group_id  = var.security_group_id
  enable_autoscaling = local.enable_autoscaling
  min_capacity       = local.min_capacity
  max_capacity       = local.max_capacity
  cpu_target_value   = local.cpu_target_value
}

module "ms_comunicaciones" {
  source = "./ecs_services"

  name                    = "${var.name_prefix}-ms-comunicaciones"
  cluster_id              = aws_ecs_cluster.this.id
  cluster_name            = aws_ecs_cluster.this.name
  subnets                 = var.vpc_private_subnets
  task_execution_role_arn = var.task_execution_role_arn

  cpu             = local.cpu
  memory          = local.memory
  container_image = "martromeros/ms-comunicaciones:latest"
  container_port  = 3002
  desired_count   = local.desired_count

  environment_variables = [
    { name = "PORT", value = "3002" },
    { name = "DB_USER", value = var.db_user },
    { name = "DB_PASSWORD", value = var.db_password },
    { name = "DB_HOST", value = var.db_host },
    { name = "DB_PORT", value = "5432" },
    { name = "DB_DATABASE", value = var.db_name },    
    { name = "UPLOAD_PATH", value = "/uploads" },
    { name = "DB_SSL", value = "true" },
    { name = "ENVIRONMENT", value = "prod" },
    { name = "MAIL_HOST", value = var.mail_host },
    { name = "MAIL_PORT", value = var.mail_port },
    { name = "MAIL_USER", value = var.mail_user },
    { name = "MAIL_PASS", value = var.mail_pass },
    { name = "AWS_REGION", value = "us-east-1" },
    { name = "SQS_QUEUE_URL", value = var.sqs_queue_url }
  ]

  target_group_arn   = var.alb_target_group_arns["comunicaciones"]
  security_group_id  = var.security_group_id
  enable_autoscaling = local.enable_autoscaling
  min_capacity       = local.min_capacity
  max_capacity       = local.max_capacity
  cpu_target_value   = local.cpu_target_value
}

module "ms_gestion" {
  source = "./ecs_services"

  name                    = "${var.name_prefix}-ms-gestion"
  cluster_id              = aws_ecs_cluster.this.id
  cluster_name            = aws_ecs_cluster.this.name
  subnets                 = var.vpc_private_subnets
  task_execution_role_arn = var.task_execution_role_arn

  cpu             = local.cpu
  memory          = local.memory
  container_image = "martromeros/ms-gestion:latest"
  container_port  = 8080
  desired_count   = local.desired_count

  environment_variables = [
    { name = "DB_URL", value = "jdbc:postgresql://${var.db_host}:5432/${var.db_name}" },
    { name = "DB_USERNAME", value = var.db_user },
    { name = "DB_PASSWORD", value = var.db_password },
    { name = "ENVIRONMENT", value = "prod" },
    { name = "SQS_QUEUE_URL", value = var.sqs_queue_url },
  ]

  target_group_arn   = var.alb_target_group_arns["gestion"]
  security_group_id  = var.security_group_id
  enable_autoscaling = local.enable_autoscaling
  min_capacity       = local.min_capacity
  max_capacity       = local.max_capacity
  cpu_target_value   = local.cpu_target_value
}

