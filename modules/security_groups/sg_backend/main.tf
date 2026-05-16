module "sg_backend" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 5.0"

  name = "backend"

  vpc_id = var.vpc_id

  egress_rules = ["all-all"]

}
