module "sg_database" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 5.0"

  name = "database"

  vpc_id = var.vpc_id

  ingress_with_source_security_group_id = [
    {
      from_port                = 5432
      to_port                  = 5432
      protocol                 = "tcp"
      description              = "Acceso a la DB desde backend"
      source_security_group_id = var.sg_backend_id
    }
  ]

  egress_rules = ["all-all"]

  tags = {
    Name = "database-sg"
  }

}
