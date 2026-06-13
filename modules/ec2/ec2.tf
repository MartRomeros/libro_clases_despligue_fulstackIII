module "ec2" {
  source                 = "terraform-aws-modules/ec2-instance/aws"
  version                = "~> 5.0"
  name                        = var.name
  instance_type               = var.instance_type
  ami                         = var.ami
  iam_instance_profile        = var.iam_instance_profile
  monitoring                  = false
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = var.security_group_ids
  associate_public_ip_address = var.associate_public_ip_address

  root_block_device = [
    {
      volume_size = var.root_volume_size
      volume_type = var.root_volume_type
    }
  ]

  user_data = <<-EOF
              #!/bin/bash
              set -e
              export DEBIAN_FRONTEND=noninteractive

              sudo apt-get update -y
              sudo apt-get install -y git docker.io

              sudo systemctl start docker
              sudo systemctl enable docker
              sudo usermod -aG docker ubuntu

              sudo snap install amazon-ssm-agent --classic
              sudo systemctl enable snap.amazon-ssm-agent.amazon-ssm-agent.service
              sudo systemctl start snap.amazon-ssm-agent.amazon-ssm-agent.service

              EOF

  tags = {
    Name = var.name
  }
}
