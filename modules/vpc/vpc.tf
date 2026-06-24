module "vpc_colegio" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.name_prefix}-vpc"
  cidr = "10.0.0.0/16"

  #Configuración dinámica de AZs
  azs             = [for s in ["a", "b"] : "us-east-1${s}"]
  private_subnets = [for s in range(4) : "10.0.${s}.0/24"]
  public_subnets  = [for s in range(2) : "10.0.10${s}.0/24"]

  private_subnet_names = [for s in range(4) : "${var.name_prefix}-private-${s}"]
  public_subnet_names  = [for s in range(2) : "${var.name_prefix}-public-${s}"]

  # Requerimiento de Gateways (Simplificado para Academy)
  enable_nat_gateway     = true
  single_nat_gateway     = true
  one_nat_gateway_per_az = false

  create_igw              = true  # Create Internet Gateway
  enable_vpn_gateway      = false # Not using VPN Gateway
  enable_dns_hostnames    = true  # Enable DNS hostnames
  enable_dns_support      = true  # Enable DNS support
  map_public_ip_on_launch = true  # Enable public IP on launch

  public_route_table_tags  = { Name = "${var.name_prefix}-public-rt" }
  private_route_table_tags = { Name = "${var.name_prefix}-private-rt" }  

  tags = {
    Terraform = "true"
    Layer     = "Network"
    Project   = "Colegio Fullstack III"
  }
}
