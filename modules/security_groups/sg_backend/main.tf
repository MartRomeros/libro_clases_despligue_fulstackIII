module "sg_backend" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 5.0"

  name   = "backend"
  vpc_id = var.vpc_id

  ingress_with_source_security_group_id = [
    {
      from_port                = 3000
      to_port                  = 3000
      protocol                 = "tcp"
      description              = "ms-auth desde ALB"
      source_security_group_id = var.alb_sg_id
    },
    {
      from_port                = 3001
      to_port                  = 3001
      protocol                 = "tcp"
      description              = "ms-asistencia desde ALB"
      source_security_group_id = var.alb_sg_id
    },
    {
      from_port                = 3002
      to_port                  = 3002
      protocol                 = "tcp"
      description              = "ms-comunicaciones desde ALB"
      source_security_group_id = var.alb_sg_id
    },
    {
      from_port                = 8080
      to_port                  = 8080
      protocol                 = "tcp"
      description              = "ms-gestion desde ALB"
      source_security_group_id = var.alb_sg_id
    }
  ]

  egress_rules = ["all-all"]
}
