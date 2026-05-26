terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
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

data "tls_public_key" "vockey_public" {
  private_key_pem = file("${path.module}/165387-vockey.pem")
}

resource "aws_key_pair" "vockey" {
  key_name   = var.ec2_key_name
  public_key = data.tls_public_key.vockey_public.public_key_openssh
}

module "vpc_colegio" {
  source = "./modules/vpc"
}

module "sg_bastion" {
  source = "./modules/security_groups/sg_bastion"
  vpc_id              = module.vpc_colegio.vpc_id
  public_ingress_cidr = var.public_ingress_cidr
}

module "sg_backend" {
  source       = "./modules/security_groups/sg_backend"
  vpc_id       = module.vpc_colegio.vpc_id
  public_sg_id = module.sg_bastion.sg_bastion_id
}

module "sg_database" {
  source        = "./modules/security_groups/sg_database"
  vpc_id        = module.vpc_colegio.vpc_id
  sg_backend_id = module.sg_backend.sg_backend_id
  sg_bastion_id = module.sg_bastion.sg_bastion_id
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

locals {
  ec2_definitions = {
    "ec2-bastion" = {
      subnet_id                   = module.vpc_colegio.public_subnets[0]
      security_group_ids          = [module.sg_bastion.sg_bastion_id]
      associate_public_ip_address = true
    }
    "ec2-api-gw" = {
      subnet_id                   = module.vpc_colegio.public_subnets[1]
      security_group_ids          = [module.sg_bastion.sg_bastion_id]
      associate_public_ip_address = true
    }
    "ec2-ms-auth" = {
      subnet_id                   = module.vpc_colegio.private_subnets[0]
      security_group_ids          = [module.sg_backend.sg_backend_id]
      associate_public_ip_address = false
    }
    "ec2-ms-asistencia" = {
      subnet_id                   = module.vpc_colegio.private_subnets[1]
      security_group_ids          = [module.sg_backend.sg_backend_id]
      associate_public_ip_address = false
    }
    "ec2-ms-gestion" = {
      subnet_id                   = module.vpc_colegio.private_subnets[2]
      security_group_ids          = [module.sg_backend.sg_backend_id]
      associate_public_ip_address = false
    }
    "ec2-ms-comunicaciones" = {
      subnet_id                   = module.vpc_colegio.private_subnets[3]
      security_group_ids          = [module.sg_backend.sg_backend_id]
      associate_public_ip_address = false
    }
  }
}

module "ec2_instances" {
  for_each = local.ec2_definitions

  source = "./modules/ec2"

  name                        = each.key
  instance_type               = var.ec2_instance_type
  ami                         = data.aws_ami.ubuntu.id
  key_name                    = aws_key_pair.vockey.key_name
  subnet_id                   = each.value.subnet_id
  security_group_ids          = each.value.security_group_ids
  associate_public_ip_address = each.value.associate_public_ip_address
  root_volume_size            = var.ec2_root_volume_size
  root_volume_type            = var.ec2_root_volume_type
}

module "api_gateway" {
  source = "./modules/api_gateway"

  name                 = "colegio-http-api"
  nginx_base_url       = "http://${module.ec2_instances["ec2-api-gw"].public_dns}"
  stage_name           = "$default"
  cors_allowed_origins = ["*"]
  tags = {
    Project = "Colegio Fullstack III"
    Layer   = "Edge"
  }
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






