locals {
  ec2_name                        = "ec2-bastion-db"
  ec2_subnet_id                   = module.vpc_colegio.private_subnets[2]
  ec2_security_group_ids          = [module.sg_backend.sg_backend_id]
  ec2_associate_public_ip_address = false
}

/* ==== Imagen de ubuntu ==== */
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }
}

/* ==== Rol Lab Academy ==== */
data "aws_iam_role" "lab_role" {
  name = "LabRole"
}

/* ==== SG del VPC Link creado aquí para evitar dependencia circular con sg_alb/sg_backend ==== */
resource "aws_security_group" "vpc_link" {
  name   = "${var.project_name}-vpc-link-sg"
  vpc_id = module.vpc_colegio.vpc_id

  egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
    description = "Hacia ALB interno"
  }

  tags = { Name = "${var.project_name}-vpc-link-sg" }
}

/* ==== LabRole es un IAM role, no un instance profile. Se crea el profile que lo envuelve. ==== */
resource "aws_iam_instance_profile" "lab_role" {
  name = "colegio-lab-instance-profile"
  role = data.aws_iam_role.lab_role.name
}

/* ==== RDS POSTGRE SQL ==== */
resource "aws_db_subnet_group" "colegio_db_subnet_group" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = module.vpc_colegio.private_subnets
  tags       = { Name = "${var.project_name}-DB-Subnet-Group" }
}

resource "aws_db_instance" "colegio_db" {
  identifier        = "${var.project_name}-db-instance"
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

  tags = { Name = "${var.project_name}-DB-PostgreSQL" }

}

/* ==== AWS SQS ==== */
resource "aws_sqs_queue" "gestion" {
  name                       = "${var.project_name}-${var.environment}-gestion"
  message_retention_seconds  = 86400
  visibility_timeout_seconds = 60

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

/* ==== VPC ==== */
module "vpc_colegio" {
  source      = "../../modules/vpc"
  name_prefix = "${var.project_name}-${var.environment}-vpc"
}



/* ==== Grupos de seguridad ==== */
/* Orden de dependencias: vpc_link_sg → sg_alb → (alb, sg_backend) */
module "sg_alb" {
  source         = "../../modules/security_groups/sg_alb"
  vpc_id         = module.vpc_colegio.vpc_id
  vpc_link_sg_id = aws_security_group.vpc_link.id
}

module "sg_backend" {
  source    = "../../modules/security_groups/sg_backend"
  vpc_id    = module.vpc_colegio.vpc_id
  alb_sg_id = module.sg_alb.sg_alb_id
}

module "sg_database" {
  source        = "../../modules/security_groups/sg_database"
  vpc_id        = module.vpc_colegio.vpc_id
  sg_backend_id = module.sg_backend.sg_backend_id
}

/* ==== EC2 Admin para administrar la bd ==== */
module "ec2_instance" {
  source = "../../modules/ec2"

  name                        = local.ec2_name
  instance_type               = var.ec2_instance_type
  ami                         = data.aws_ami.ubuntu.id
  iam_instance_profile        = aws_iam_instance_profile.lab_role.name
  subnet_id                   = local.ec2_subnet_id
  security_group_ids          = local.ec2_security_group_ids
  associate_public_ip_address = local.ec2_associate_public_ip_address
  root_volume_size            = var.ec2_root_volume_size
  root_volume_type            = var.ec2_root_volume_type

  depends_on = [module.vpc_colegio]
}

/* ==== AWS ALB ==== */
module "alb" {
  source = "../../modules/alb"

  name               = "${var.project_name}-internal-alb"
  vpc_id             = module.vpc_colegio.vpc_id
  subnets            = [module.vpc_colegio.private_subnets[0], module.vpc_colegio.private_subnets[1]]
  security_group_ids = [module.sg_alb.sg_alb_id]

  services = {
    auth           = { port = 3000 }
    asistencia     = { port = 3001 }
    comunicaciones = { port = 3002 }
    gestion        = { port = 8080 }
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

/* ==== AWS API GATEWAY (HTTP) ==== */
module "api_gateway" {
  source = "../../modules/api_gateway"

  name                 = "${var.project_name}-http-api"
  alb_listener_arn     = module.alb.alb_listener_arn
  vpc_link_sg_id       = aws_security_group.vpc_link.id
  vpc_link_subnet_ids  = [module.vpc_colegio.private_subnets[0], module.vpc_colegio.private_subnets[1]]
  stage_name           = "$default"
  cors_allowed_origins = ["*"]
  tags = {
    Project = "${var.project_name}-http-apigw"
    Layer   = "Edge"
  }
}

/* ==== AWS ECS con Fargate ==== */
module "ecs" {
  source = "../../modules/ecs"

  name_prefix             = "${var.project_name}-${var.environment}-ecs"
  vpc_private_subnets     = module.vpc_colegio.private_subnets
  alb_target_group_arns   = module.alb.alb_target_group_arns
  security_group_id       = module.sg_backend.sg_backend_id
  task_execution_role_arn = data.aws_iam_role.lab_role.arn

  db_host       = aws_db_instance.colegio_db.address
  db_name       = var.db_name
  db_user       = var.db_user
  db_password   = var.db_password
  sqs_queue_url = aws_sqs_queue.gestion.url

  mail_host = var.mail_host
  mail_pass = var.mail_pass
  mail_user = var.mail_user
  mail_port = var.mail_port

}

