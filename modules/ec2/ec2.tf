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
              sudo apt-get install -y ca-certificates curl gnupg jq git docker.io postgresql-client

              sudo systemctl start docker
              sudo systemctl enable docker
              sudo usermod -aG docker ubuntu

              # Amazon SSM Agent (administración sin SSH)
              sudo snap install amazon-ssm-agent --classic
              sudo systemctl enable snap.amazon-ssm-agent.amazon-ssm-agent.service
              sudo systemctl start snap.amazon-ssm-agent.amazon-ssm-agent.service

              # ngrok
              curl -sSL https://ngrok-agent.s3.amazonaws.com/ngrok.asc | sudo tee /etc/apt/trusted.gpg.d/ngrok.asc >/dev/null
              echo "deb https://ngrok-agent.s3.amazonaws.com buster main" | sudo tee /etc/apt/sources.list.d/ngrok.list
              sudo apt-get update -y
              sudo apt-get install -y ngrok
              sudo -u ubuntu ngrok config add-authtoken ${var.ngrok_authtoken}

              # n8n vía Docker
              docker volume create n8n_data
              docker run -d \
                --name n8n \
                --restart unless-stopped \
                -p ${var.n8n_port}:5678 \
                -v n8n_data:/home/node/.n8n \
                -e N8N_BASIC_AUTH_ACTIVE=true \
                -e N8N_BASIC_AUTH_USER=${var.n8n_basic_auth_user} \
                -e N8N_BASIC_AUTH_PASSWORD=${var.n8n_basic_auth_password} \
                ${var.n8n_image}

              # Servicio systemd para mantener el túnel HTTPS de ngrok activo
              cat <<UNIT | sudo tee /etc/systemd/system/ngrok.service
              [Unit]
              Description=ngrok tunnel for n8n
              After=network-online.target docker.service
              Wants=network-online.target

              [Service]
              User=ubuntu
              Environment=HOME=/home/ubuntu
              ExecStart=/usr/bin/env ngrok http ${var.n8n_port} --log=stdout
              Restart=always
              RestartSec=5

              [Install]
              WantedBy=multi-user.target
              UNIT

              sudo systemctl daemon-reload
              sudo systemctl enable ngrok.service
              sudo systemctl start ngrok.service
              EOF

  tags = {
    Name = var.name
  }
}
