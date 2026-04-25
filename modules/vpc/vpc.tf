module "vpc_colegio" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "colegio-vpc"
  cidr = "10.0.0.0/16"

  #Configuración dinámica de AZs
  azs             = [for s in ["a", "b"] : "us-east-1${s}"]
  private_subnets = [for s in range(4) : "10.0.${s}.0/24"]
  public_subnets  = [for s in range(2) : "10.0.10${s}.0/24"]

  public_route_table_tags  = { Name = "tabla-publica-colegio" }
  private_route_table_tags = { Name = "tabla-privada-colegio" }

  # CRÍTICO: Permitir resolución DNS para que Lambda encuentre a RDS
  enable_dns_hostnames = true
  enable_dns_support   = true

  # Requerimiento de Gateways (Simplificado para Academy)
  enable_nat_gateway     = true
  single_nat_gateway     = true
  one_nat_gateway_per_az = false

  tags = {
    Terraform = "true"
    Layer     = "Network"
  }
}
