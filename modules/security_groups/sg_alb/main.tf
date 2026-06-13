module "sg_alb" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 5.0"

  name   = "alb"
  vpc_id = var.vpc_id

  ingress_with_source_security_group_id = [
    {
      from_port                = 80
      to_port                  = 80
      protocol                 = "tcp"
      description              = "HTTP desde VPC Link"
      source_security_group_id = var.vpc_link_sg_id
    }
  ]

  # CIDR egress para evitar dependencia circular con sg_backend
  egress_with_cidr_blocks = [
    {
      from_port   = 3000
      to_port     = 3000
      protocol    = "tcp"
      description = "ms-auth"
      cidr_blocks = var.vpc_cidr
    },
    {
      from_port   = 3001
      to_port     = 3001
      protocol    = "tcp"
      description = "ms-asistencia"
      cidr_blocks = var.vpc_cidr
    },
    {
      from_port   = 3002
      to_port     = 3002
      protocol    = "tcp"
      description = "ms-comunicaciones"
      cidr_blocks = var.vpc_cidr
    },
    {
      from_port   = 8080
      to_port     = 8080
      protocol    = "tcp"
      description = "ms-gestion"
      cidr_blocks = var.vpc_cidr
    }
  ]
}
