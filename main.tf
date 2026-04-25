terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"

  # Ignorar configuraciones que AWS Academy bloquea
  skip_metadata_api_check     = true
  skip_region_validation      = true
  skip_credentials_validation = true
  skip_requesting_account_id  = true
}

module "vpc" {
  source = "./modules/vpc"
}

module "security_groups" {
  source = "./modules/security_groups"
  vpc_id = module.vpc.vpc_id
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }
}

resource "aws_db_subnet_group" "colegio_db_subnet_group" {
  name       = "colegio-db-subnets"
  subnet_ids = module.vpc.private_subnets
  tags       = { Name = "DB Subnet Group Colegio" }
}

resource "aws_db_instance" "postgres_colegio" {
  identifier        = "db-colegio-instancia"
  engine            = "postgres"
  engine_version    = "15"
  instance_class    = "db.t3.micro"
  allocated_storage = 20
  storage_type      = "gp2"

  db_name  = var.db_name
  username = var.username
  password = var.password

  db_subnet_group_name   = aws_db_subnet_group.colegio_db_subnet_group.name
  vpc_security_group_ids = [module.security_groups.database_sg_id]
  publicly_accessible    = false
  skip_final_snapshot    = true

  tags = { Name = "RDS-Postgres-Colegio" }
}

module "auth_lambda" {
  source = "./modules/auth_lambda"

  vpc_id            = module.vpc.vpc_id
  private_subnets   = module.vpc.private_subnets
  security_group_id = module.security_groups.backend_sg_id
  db_host           = aws_db_instance.postgres_colegio.address
  db_user           = var.username
  db_password       = var.password
  db_name           = var.db_name
  jwt_secret        = var.jwt_secret
  frontend_url      = "*"
  image_uri         = "${module.ecr_auth.repository_url}:latest"
}

# Repositorio ECR
module "ecr_auth" {
  source          = "./modules/ecr"
  repository_name = "colegio-ms-auth"
  environment     = "dev"
}

output "api_endpoint" {
  value = module.auth_lambda.api_url
}

output "ecr_repository_url" {
  value = module.ecr_auth.repository_url
}

output "public_subnet_id" {
  value = module.vpc.public_subnets[0]
}

output "bastion_sg_id" {
  value = module.security_groups.bastion_sg_id
}

output "rds_endpoint" {
  value = aws_db_instance.postgres_colegio.address
}

output "ubuntu_ami_id" {
  value = data.aws_ami.ubuntu.id
}

