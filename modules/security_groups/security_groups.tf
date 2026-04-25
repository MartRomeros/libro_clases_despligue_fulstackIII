module "security_groups_backend" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 5.0"

  name        = "colegio-security-group-backend"
  description = "SG para servidor privado de aplicaciones"
  vpc_id      = var.vpc_id

  ingress_with_source_security_group_id = [
    {
      from_port                = 3000
      to_port                  = 3000
      protocol                 = "tcp"
      description              = "Trafico desde el ALB Interno"
      source_security_group_id = aws_security_group.alb_sg.id
    },
    {
      from_port                = 22
      to_port                  = 22
      protocol                 = "tcp"
      description              = "SSH desde el Bastion"
      source_security_group_id = aws_security_group.sg_bastion.id
    }
  ]

  egress_rules = ["all-all"]

  tags = { Name = "backend-sg" }
}

# Security Group para el ALB Interno
resource "aws_security_group" "alb_sg" {
  name        = "colegio-alb-sg"
  description = "Permitir trafico desde API Gateway VPC Link"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # El VPC Link lo filtrara
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

module "security_groups_database" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 5.0"

  name        = "colegio-security-group-database"
  description = "SG para RDS"
  vpc_id      = var.vpc_id

  ingress_with_source_security_group_id = [
    {
      from_port                = 5432
      to_port                  = 5432
      protocol                 = "tcp"
      description              = "Acceso a la DB desde backend"
      source_security_group_id = module.security_groups_backend.security_group_id
    },
    {
      from_port                = 5432
      to_port                  = 5432
      protocol                 = "tcp"
      description              = "Acceso a la DB desde backend"
      source_security_group_id = aws_security_group.sg_bastion.id
    },
  ]

  tags = {
    Name = "database-sg"
  }
}

resource "aws_security_group" "sg_bastion" {
  name        = "colegio-bastion-sg"
  description = "Permitir SSH desde la ip"
  vpc_id      = var.vpc_id

  ingress {
    from_port = 22
    to_port   = 22
    protocol  = "tcp"
    # IMPORTANTE: Cambia esto por tu IP pública real (ej: "201.2.3.4/32") 
    # para que sea seguro.
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
