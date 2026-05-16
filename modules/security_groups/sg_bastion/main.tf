module "sg_bastion" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 5.0"

  name = "bastion"

  vpc_id = var.vpc_id

  ingress_with_cidr_blocks = [
    {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      description = "SSH"
      cidr_blocks = "0.0.0.0/0"
    }
  ]

  egress_with_cidr_blocks = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      description = "All outbound"
      cidr_blocks = "0.0.0.0/0"
    }
  ]


}
