module "sg_ec2_admin" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 5.0"

  name   = "ec2-admin"
  vpc_id = var.vpc_id

  # Sin ingress: administración vía SSM Session Manager (no requiere puertos entrantes, sin SSH)

  egress_with_cidr_blocks = [
    {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      description = "Salida HTTP (apt, actualizaciones)"
      cidr_blocks = "0.0.0.0/0"
    },
    {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      description = "Salida HTTPS (SSM, docker pull, ngrok)"
      cidr_blocks = "0.0.0.0/0"
    },
    {
      from_port   = 53
      to_port     = 53
      protocol    = "udp"
      description = "Resolucion DNS del resolver de la VPC"
      cidr_blocks = var.vpc_cidr
    },
    {
      from_port   = 53
      to_port     = 53
      protocol    = "tcp"
      description = "Resolucion DNS del resolver de la VPC (fallback TCP)"
      cidr_blocks = var.vpc_cidr
    },
    {
      from_port   = 5432
      to_port     = 5432
      protocol    = "tcp"
      description = "Acceso al RDS PostgreSQL (psql client y n8n)"
      cidr_blocks = var.vpc_cidr
    }
  ]

  tags = {
    Name = "ec2-admin-sg"
  }
}
