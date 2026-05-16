terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  # Ignorar configuraciones que AWS Academy bloquea
  skip_metadata_api_check     = true
  skip_region_validation      = true
  skip_credentials_validation = true
  skip_requesting_account_id  = true
}

locals {
  ecr_repositories = {
    ecr_colegio_auth           = "ecr-colegio-auth"
    ecr_colegio_attendance     = "ecr-colegio-attendance"
    ecr_colegio_gestion        = "ecr-colegio-gestion"
    ecr_colegio_comunicaciones = "ecr-colegio-comunicaciones"
  }
}

module "vpc_colegio" {
  source = "./modules/vpc"
}

module "sg_backend" {
  source = "./modules/security_groups/sg_backend"
  vpc_id = module.vpc_colegio.vpc_id
}

module "sg_bastion" {
  source = "./modules/security_groups/sg_bastion"
  vpc_id = module.vpc_colegio.vpc_id
}


module "sg_database" {
  source        = "./modules/security_groups/sg_database"
  vpc_id        = module.vpc_colegio.vpc_id
  sg_backend_id = module.sg_backend.sg_backend_id
  sg_bastion_id = module.sg_bastion.sg_bastion_id
}

module "ecr_colegio" {
  for_each = local.ecr_repositories
  source   = "./modules/ecr"
  name     = each.value
}

module "ms_authentication_lambda" {
  source = "./modules/lambdas/microservice_lambda"

  function_name     = "ms-auth-function"
  image_uri         = "${module.ecr_colegio["ecr_colegio_auth"].ecr_url}:${var.lambda_image_tag}"
  role_arn          = data.aws_iam_role.lab_role.arn
  private_subnets   = module.vpc_colegio.private_subnets
  security_group_id = module.sg_backend.sg_backend_id
  memory_size       = var.lambda_memory_size
  timeout           = var.lambda_timeout
  environment_variables = {
    PORT        = "3000"
    DB_HOST     = aws_db_instance.colegio_db.address
    DB_PORT     = "5432"
    DB_DATABASE = var.db_name
    DB_USER     = var.db_user
    DB_PASSWORD = var.db_password
    JWT_SECRET  = var.jwt_secret
    DB_SSL      = true
  }
}

module "ms_attendance_lambda" {
  source = "./modules/lambdas/microservice_lambda"

  function_name     = "ms-attendance-function"
  image_uri         = "${module.ecr_colegio["ecr_colegio_attendance"].ecr_url}:${var.lambda_image_tag}"
  role_arn          = data.aws_iam_role.lab_role.arn
  private_subnets   = module.vpc_colegio.private_subnets
  security_group_id = module.sg_backend.sg_backend_id
  memory_size       = var.lambda_memory_size
  timeout           = var.lambda_timeout
  environment_variables = {
    PORT        = "3001"
    DB_HOST     = aws_db_instance.colegio_db.address
    DB_PORT     = "5432"
    DB_DATABASE = var.db_name
    DB_USER     = var.db_user
    DB_PASSWORD = var.db_password
    JWT_SECRET  = var.jwt_secret
    DB_SSL      = true
  }
}

module "ms_gestion_lambda" {
  source = "./modules/lambdas/microservice_lambda"

  function_name     = "ms-gestion-function"
  image_uri         = "${module.ecr_colegio["ecr_colegio_gestion"].ecr_url}:${var.lambda_image_tag}"
  role_arn          = data.aws_iam_role.lab_role.arn
  private_subnets   = module.vpc_colegio.private_subnets
  security_group_id = module.sg_backend.sg_backend_id
  memory_size       = var.lambda_memory_size
  timeout           = var.lambda_timeout
  environment_variables = {
    DB_URL      = "jdbc:postgresql://${aws_db_instance.colegio_db.address}:5432/${var.db_name}"
    DB_USERNAME = var.db_user
    DB_PASSWORD = var.db_password
  }
}

module "ms_comunicaciones_lambda" {
  source = "./modules/lambdas/microservice_lambda"

  function_name     = "ms-comunicaciones-function"
  image_uri         = "${module.ecr_colegio["ecr_colegio_comunicaciones"].ecr_url}:${var.lambda_image_tag}"
  role_arn          = data.aws_iam_role.lab_role.arn
  private_subnets   = module.vpc_colegio.private_subnets
  security_group_id = module.sg_backend.sg_backend_id
  memory_size       = var.lambda_memory_size
  timeout           = var.lambda_timeout
  environment_variables = {
    PORT        = "3002"
    DB_HOST     = aws_db_instance.colegio_db.address
    DB_PORT     = "5432"
    DB_DATABASE = var.db_name
    DB_USER     = var.db_user
    DB_PASSWORD = var.db_password
    API_RESEND  = var.resend_api_key
    UPLOAD_PATH = "/tmp"
  }
}

locals {
  lambda_log_groups = {
    auth       = module.ms_authentication_lambda.function_name
    attendance = module.ms_attendance_lambda.function_name
    gestion    = module.ms_gestion_lambda.function_name
    mensajes   = module.ms_comunicaciones_lambda.function_name
  }
}

resource "aws_cloudwatch_log_group" "lambda" {
  for_each = local.lambda_log_groups

  name              = "/aws/lambda/${each.value}"
  retention_in_days = 14
}

module "api_gateway_http" {
  source = "./modules/api_gateway_http"
  lambda_integrations = {
    auth = {
      invoke_arn    = module.ms_authentication_lambda.invoke_arn
      function_name = module.ms_authentication_lambda.function_name
      route_prefix  = "auth"
    }

    attendance = {
      invoke_arn    = module.ms_attendance_lambda.invoke_arn
      function_name = module.ms_attendance_lambda.function_name
      route_prefix  = "attendance"
    }

    gestion = {
      invoke_arn    = module.ms_gestion_lambda.invoke_arn
      function_name = module.ms_gestion_lambda.function_name
      route_prefix  = "gestion"
    }

    comunicaciones = {
      invoke_arn    = module.ms_comunicaciones_lambda.invoke_arn
      function_name = module.ms_comunicaciones_lambda.function_name
      route_prefix  = "comunicaciones"
    }
  }
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }
}

data "aws_iam_role" "lab_role" {
  name = "LabRole"
}

resource "aws_db_subnet_group" "colegio_db_subnet_group" {
  name       = "colegio-db-subnet-group"
  subnet_ids = module.vpc_colegio.private_subnets
  tags       = { Name = "DB Subnet Group" }
}

resource "aws_db_instance" "colegio_db" {
  identifier        = "db-colegio-instance"
  engine            = "postgres"
  engine_version    = "15"
  instance_class    = "db.t3.micro"
  allocated_storage = 20
  storage_type      = "gp2"

  db_name  = var.db_name
  username = var.db_user
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.colegio_db_subnet_group.name
  vpc_security_group_ids = [module.sg_database.sg_database_id]
  publicly_accessible    = false
  skip_final_snapshot    = true

  tags = { Name = "ColegioDB" }

}

resource "aws_ecr_repository_policy" "repo_policy" {
  for_each   = module.ecr_colegio
  repository = each.value.ecr_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowLambdaAndLabRolePull"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
          AWS     = data.aws_iam_role.lab_role.arn
        }
        Action = [
          "ecr:BatchGetImage",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchCheckLayerAvailability"
        ]
      }
    ]
  })
}







