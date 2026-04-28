# Módulos de Terraform — Diseño, Reutilización y Composición

## Anatomía de un Módulo Bien Diseñado

```
modules/vpc/
├── main.tf         ← recursos principales
├── variables.tf    ← inputs del módulo (la interfaz pública)
├── outputs.tf      ← outputs del módulo (lo que expone)
├── versions.tf     ← required_providers y required_version
├── locals.tf       ← cálculos internos
├── data.tf         ← data sources
└── README.md       ← documentación con inputs, outputs y ejemplos
```

**Regla clave:** el módulo es como una función — su interfaz (variables y outputs)
es el contrato público. La implementación puede cambiar mientras el contrato sea estable.

---

## versions.tf — Fijar Versiones para Reproducibilidad

```hcl
# modules/vpc/versions.tf — SIEMPRE en cada módulo
terraform {
  required_version = ">= 1.5.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0, < 6.0"
    }
  }
}
```

---

## Módulo VPC — Ejemplo Completo

```hcl
# modules/vpc/variables.tf
variable "name" {
  description = "Name prefix for all resources in this VPC"
  type        = string
}

variable "cidr_block" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.cidr_block, 0))
    error_message = "cidr_block must be a valid CIDR notation."
  }
}

variable "availability_zones" {
  description = "List of AZs to use (minimum 2 recommended)"
  type        = list(string)

  validation {
    condition     = length(var.availability_zones) >= 2
    error_message = "At least 2 availability zones required for HA."
  }
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets (one per AZ)"
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets (one per AZ)"
  type        = list(string)
}

variable "enable_nat_gateway" {
  description = "Create NAT Gateway for private subnet internet access"
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Use single NAT Gateway (cheaper but less HA). Recommended only for dev."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# modules/vpc/main.tf
locals {
  nat_gateway_count = var.enable_nat_gateway ? (
    var.single_nat_gateway ? 1 : length(var.availability_zones)
  ) : 0
}

resource "aws_vpc" "this" {
  cidr_block           = var.cidr_block
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(var.tags, {
    Name = var.name
  })
}

resource "aws_subnet" "private" {
  count = length(var.private_subnet_cidrs)

  vpc_id            = aws_vpc.this.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = merge(var.tags, {
    Name = "${var.name}-private-${var.availability_zones[count.index]}"
    Tier = "private"
  })
}

resource "aws_subnet" "public" {
  count = length(var.public_subnet_cidrs)

  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = merge(var.tags, {
    Name = "${var.name}-public-${var.availability_zones[count.index]}"
    Tier = "public"
  })
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.name}-igw"
  })
}

resource "aws_eip" "nat" {
  count  = local.nat_gateway_count
  domain = "vpc"

  tags = merge(var.tags, {
    Name = "${var.name}-nat-eip-${count.index + 1}"
  })
}

resource "aws_nat_gateway" "this" {
  count = local.nat_gateway_count

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = merge(var.tags, {
    Name = "${var.name}-nat-${count.index + 1}"
  })

  depends_on = [aws_internet_gateway.this]
}

resource "aws_route_table" "private" {
  count  = length(var.private_subnet_cidrs)
  vpc_id = aws_vpc.this.id

  dynamic "route" {
    for_each = var.enable_nat_gateway ? [1] : []
    content {
      cidr_block     = "0.0.0.0/0"
      nat_gateway_id = var.single_nat_gateway ? aws_nat_gateway.this[0].id : aws_nat_gateway.this[count.index].id
    }
  }

  tags = merge(var.tags, {
    Name = "${var.name}-private-rt-${count.index + 1}"
  })
}

resource "aws_route_table_association" "private" {
  count          = length(var.private_subnet_cidrs)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = merge(var.tags, {
    Name = "${var.name}-public-rt"
  })
}

resource "aws_route_table_association" "public" {
  count          = length(var.public_subnet_cidrs)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# modules/vpc/outputs.tf
output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.this.id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.this.cidr_block
}

output "private_subnet_ids" {
  description = "List of private subnet IDs"
  value       = aws_subnet.private[*].id
}

output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value       = aws_subnet.public[*].id
}

output "nat_gateway_ids" {
  description = "List of NAT Gateway IDs"
  value       = aws_nat_gateway.this[*].id
}
```

---

## Usar un Módulo — Formas de Llamarlo

```hcl
# Módulo local
module "vpc" {
  source = "../../modules/vpc"  # ruta relativa

  name                 = "myapp-prod"
  cidr_block           = "10.0.0.0/16"
  availability_zones   = ["us-east-1a", "us-east-1b", "us-east-1c"]
  private_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnet_cidrs  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
  enable_nat_gateway   = true
  single_nat_gateway   = false  # HA en producción

  tags = {
    Environment = "prod"
    Team        = "platform"
  }
}

# Usar los outputs del módulo
resource "aws_eks_cluster" "main" {
  vpc_config {
    subnet_ids = module.vpc.private_subnet_ids
  }
}

# Módulo del Terraform Registry (público)
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"  # ← SIEMPRE versionar módulos externos

  name = "myapp-prod"
  cidr = "10.0.0.0/16"

  azs             = ["us-east-1a", "us-east-1b", "us-east-1c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = false
}

# Módulo en Git con versión por tag
module "vpc" {
  source = "git::https://github.com/org/terraform-modules.git//modules/vpc?ref=v2.1.0"
  # ref puede ser: tag, branch, o commit hash
}

# Módulo en Git por SSH
module "vpc" {
  source = "git::git@github.com:org/terraform-modules.git//modules/vpc?ref=v2.1.0"
}
```

---

## Composición de Módulos — Módulos de Nivel Superior

```hcl
# environments/prod/main.tf — componiendo módulos especializados

# Networking
module "networking" {
  source = "../../modules/vpc"
  # ...
}

# Compute
module "eks" {
  source = "../../modules/eks-cluster"

  # Consumir outputs del módulo de networking
  vpc_id          = module.networking.vpc_id
  private_subnets = module.networking.private_subnet_ids
  # ...
}

# Database
module "rds" {
  source = "../../modules/rds-aurora"

  vpc_id          = module.networking.vpc_id
  subnet_ids      = module.networking.private_subnet_ids
  # ...
}

# Passing outputs entre módulos
output "eks_cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.eks.cluster_endpoint
}

output "rds_endpoint" {
  description = "RDS cluster endpoint"
  value       = module.rds.cluster_endpoint
  sensitive   = true
}
```

---

## Principios de Diseño de Módulos

```
1. PROPÓSITO ÚNICO
   Un módulo hace una cosa bien: VPC, EKS cluster, RDS, etc.
   No un módulo "infraestructura-completa" que hace todo.

2. INTERFAZ ESTABLE
   Las variables y outputs son el contrato público.
   Cambiar un nombre de variable es un breaking change.
   Usar versioning semántico: major.minor.patch

3. DEFAULTS SENSATOS
   Los valores por defecto deben ser seguros para producción.
   enable_deletion_protection = true (por defecto)
   No: enable_deletion_protection = false

4. NO INCLUIR CONFIGURACIÓN DE ENTORNO
   El módulo no sabe si es dev o prod.
   El que llama al módulo pasa los valores específicos del entorno.

5. OUTPUTS COMPLETOS
   Exponer todo lo que los consumidores puedan necesitar.
   No solo el ID — también ARN, nombre, endpoint, etc.
   Es fácil agregar outputs; quitarlos es un breaking change.

6. DOCUMENTACIÓN COMO CÓDIGO
   README.md con: propósito, uso, inputs, outputs, ejemplos
   Usar terraform-docs para generar documentación automáticamente
```
