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

module "vpc_colegio" {
  source = "./modules/vpc"
}

# SG del VPC Link creado aquí para evitar dependencia circular con sg_alb/sg_backend
resource "aws_security_group" "vpc_link" {
  name   = "colegio-vpc-link-sg"
  vpc_id = module.vpc_colegio.vpc_id

  egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
    description = "Hacia ALB interno"
  }

  tags = { Name = "colegio-vpc-link-sg" }
}

# Orden de dependencias: vpc_link_sg → sg_alb → (alb, sg_backend)
module "sg_alb" {
  source         = "./modules/security_groups/sg_alb"
  vpc_id         = module.vpc_colegio.vpc_id
  vpc_link_sg_id = aws_security_group.vpc_link.id
}

module "sg_backend" {
  source    = "./modules/security_groups/sg_backend"
  vpc_id    = module.vpc_colegio.vpc_id
  alb_sg_id = module.sg_alb.sg_alb_id
}

module "sg_database" {
  source        = "./modules/security_groups/sg_database"
  vpc_id        = module.vpc_colegio.vpc_id
  sg_backend_id = module.sg_backend.sg_backend_id
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

# LabRole es un IAM role, no un instance profile. Se crea el profile que lo envuelve.
resource "aws_iam_instance_profile" "lab_role" {
  name = "colegio-lab-instance-profile"
  role = data.aws_iam_role.lab_role.name
}

locals {
  ec2_definitions = {
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
    "ec2-bastion-db" = {
      subnet_id                   = module.vpc_colegio.private_subnets[2]
      security_group_ids          = [module.sg_database.sg_database_id]
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
  iam_instance_profile        = aws_iam_instance_profile.lab_role.name
  subnet_id                   = each.value.subnet_id
  security_group_ids          = each.value.security_group_ids
  associate_public_ip_address = each.value.associate_public_ip_address
  root_volume_size            = var.ec2_root_volume_size
  root_volume_type            = var.ec2_root_volume_type
}

module "alb" {
  source = "./modules/alb"

  name               = var.alb_name
  vpc_id             = module.vpc_colegio.vpc_id
  subnets            = [module.vpc_colegio.private_subnets[0], module.vpc_colegio.private_subnets[1]]
  security_group_ids = [module.sg_alb.sg_alb_id]

  services = {
    auth = {
      instance_id = module.ec2_instances["ec2-ms-auth"].instance_id
      port        = 3000
    }
    asistencia = {
      instance_id = module.ec2_instances["ec2-ms-asistencia"].instance_id
      port        = 3001
    }
    comunicaciones = {
      instance_id = module.ec2_instances["ec2-ms-comunicaciones"].instance_id
      port        = 3002
    }
    gestion = {
      instance_id = module.ec2_instances["ec2-ms-gestion"].instance_id
      port        = 8080
    }
  }

  routes = [
    # Prioridad alta: /api/docentes/cursos debe ir a asistencia antes que la regla genérica de gestion
    {
      priority      = 10
      service_key   = "asistencia"
      path_patterns = ["/api/docentes/cursos", "/api/docentes/cursos/*"]
    },
    {
      priority      = 20
      service_key   = "auth"
      path_patterns = ["/api/auth/*", "/api/teachers/*", "/api/students/*", "/api/admin/*"]
    },
    {
      priority      = 30
      service_key   = "asistencia"
      path_patterns = ["/api/anotaciones", "/api/anotaciones/*", "/api/asistencia", "/api/asistencia/*", "/api/cursos/*"]
    },
    {
      priority      = 40
      service_key   = "comunicaciones"
      path_patterns = ["/api/mensajes", "/api/mensajes/*"]
    },
    # Gestion: dividido en 3 reglas por el límite de 5 path_patterns por regla del ALB
    {
      priority      = 50
      service_key   = "gestion"
      path_patterns = ["/api/academico", "/api/academico/*", "/api/docentes/*", "/api/estudiantes", "/api/estudiantes/*"]
    },
    {
      priority      = 60
      service_key   = "gestion"
      path_patterns = ["/api/evaluaciones", "/api/evaluaciones/*", "/api/notas", "/api/notas/*", "/api/usuarios"]
    },
    {
      priority      = 70
      service_key   = "gestion"
      path_patterns = ["/api/usuarios/*"]
    }
  ]
}

module "api_gateway" {
  source = "./modules/api_gateway"

  name                 = "colegio-http-api"
  alb_listener_arn     = module.alb.alb_listener_arn
  vpc_link_sg_id       = aws_security_group.vpc_link.id
  vpc_link_subnet_ids  = [module.vpc_colegio.private_subnets[0], module.vpc_colegio.private_subnets[1]]
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
