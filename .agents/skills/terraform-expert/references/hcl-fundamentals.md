# HCL Fundamentals — Variables, Tipos, Expresiones y Funciones

## Variables — Tipos y Validación

```hcl
# variables.tf — bien documentadas y tipadas

# String simple
variable "environment" {
  description = "Deployment environment: dev, staging, or prod"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

# Número con rango
variable "instance_count" {
  description = "Number of EC2 instances to create"
  type        = number
  default     = 2

  validation {
    condition     = var.instance_count >= 1 && var.instance_count <= 20
    error_message = "instance_count must be between 1 and 20."
  }
}

# Booleano
variable "enable_deletion_protection" {
  description = "Enable deletion protection on the RDS instance"
  type        = bool
  default     = true
}

# Lista de strings
variable "availability_zones" {
  description = "List of AZs to use"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

# Mapa de strings
variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# Objeto con estructura fija — tipo el más expresivo
variable "database_config" {
  description = "RDS database configuration"
  type = object({
    instance_class    = string
    allocated_storage = number
    engine_version    = string
    multi_az          = optional(bool, true)   # optional con default (TF 1.3+)
    backup_retention  = optional(number, 7)
  })
  default = {
    instance_class    = "db.t3.medium"
    allocated_storage = 100
    engine_version    = "15.4"
  }
}

# Lista de objetos
variable "subnets" {
  description = "Subnet configurations"
  type = list(object({
    name       = string
    cidr_block = string
    public     = bool
  }))
  default = []
}

# Set — lista sin duplicados y sin orden
variable "allowed_account_ids" {
  description = "AWS account IDs allowed to assume the cross-account role"
  type        = set(string)
}

# Variable sensible — no se muestra en logs ni en plan
variable "db_password" {
  description = "Master password for RDS"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.db_password) >= 16
    error_message = "Database password must be at least 16 characters."
  }
}

# Variable nullable — puede ser null explícitamente
variable "kms_key_id" {
  description = "KMS key ARN for encryption, null for AWS managed key"
  type        = string
  default     = null
  nullable    = true
}
```

---

## Locals — Calcular Valores Derivados

```hcl
# locals.tf — valores calculados o complejos
locals {
  # Nombre base para recursos — consistencia en toda la configuración
  name_prefix = "${var.project}-${var.environment}"

  # Tags comunes para todos los recursos
  common_tags = merge(var.tags, {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "terraform"
    Repository  = "https://github.com/org/infrastructure"
  })

  # Lógica condicional
  instance_type = var.environment == "prod" ? "t3.large" : "t3.micro"

  # Transformar una lista en un mapa para for_each
  subnet_map = { for subnet in var.subnets : subnet.name => subnet }

  # Valor calculado con funciones
  bucket_name = lower(replace("${local.name_prefix}-artifacts", "_", "-"))

  # Condicional para activar features según el entorno
  enable_enhanced_monitoring = contains(["staging", "prod"], var.environment)

  # Calcular AZs disponibles
  az_count = min(length(data.aws_availability_zones.available.names), 3)
  azs      = slice(data.aws_availability_zones.available.names, 0, local.az_count)
}
```

---

## Outputs — Exponer Valores del Módulo

```hcl
# outputs.tf — outputs bien documentados

output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.main.id
}

output "private_subnet_ids" {
  description = "List of private subnet IDs"
  value       = aws_subnet.private[*].id
}

# Output sensible — no se muestra en logs
output "db_connection_string" {
  description = "Database connection string (sensitive)"
  value       = "postgresql://${aws_db_instance.main.endpoint}/${aws_db_instance.main.db_name}"
  sensitive   = true
}

# Output con dependencia explícita
output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.main.dns_name
  depends_on  = [aws_lb_listener.https]  # esperar a que el listener esté listo
}

# Output de todo un objeto
output "ecs_cluster" {
  description = "ECS cluster details"
  value = {
    id   = aws_ecs_cluster.main.id
    name = aws_ecs_cluster.main.name
    arn  = aws_ecs_cluster.main.arn
  }
}
```

---

## Expresiones y Funciones Esenciales

```hcl
# ── Condicionales ────────────────────────────────────────────────────
resource "aws_instance" "web" {
  ami           = var.ami_id
  instance_type = var.environment == "prod" ? "t3.large" : "t3.micro"

  # Condicional para un bloque entero
  dynamic "ebs_block_device" {
    for_each = var.environment == "prod" ? [1] : []
    content {
      device_name = "/dev/sdf"
      volume_size = 100
      encrypted   = true
    }
  }
}

# ── For expressions ──────────────────────────────────────────────────
locals {
  # Lista → lista transformada
  upper_names = [for name in var.names : upper(name)]

  # Lista → mapa
  name_to_id = { for idx, name in var.names : name => idx }

  # Mapa → lista filtrada
  active_users = [for user, attrs in var.users : user if attrs.active]

  # Mapa → mapa filtrado y transformado
  prod_instances = {
    for name, config in var.instances :
    name => merge(config, { environment = "prod" })
    if config.enable_in_prod
  }

  # Nested for con flatten
  all_sg_rules = flatten([
    for sg_name, sg in var.security_groups : [
      for rule in sg.ingress_rules : {
        sg_name   = sg_name
        from_port = rule.from_port
        to_port   = rule.to_port
        protocol  = rule.protocol
        cidr      = rule.cidr
      }
    ]
  ])
}

# ── String Functions ─────────────────────────────────────────────────
locals {
  # format() — como printf
  bucket_name   = format("%s-%s-artifacts", var.project, var.environment)

  # lower, upper, title
  normalized    = lower(trimspace(var.name))

  # replace
  safe_name     = replace(var.name, " ", "-")

  # split, join
  parts         = split(".", "us-east-1.prod.myapp")
  joined        = join("-", ["us", "east", "1"])

  # substr
  short_env     = substr(var.environment, 0, 3)  # "pro", "dev", "sta"

  # regex — extraer parte de un string
  account_id    = regex("arn:aws:iam::([0-9]+):.*", var.role_arn)[0]

  # templatefile — cargar template desde archivo
  user_data     = templatefile("${path.module}/templates/user_data.sh.tpl", {
    app_name    = var.app_name
    environment = var.environment
    bucket      = aws_s3_bucket.artifacts.bucket
  })
}

# ── Collection Functions ─────────────────────────────────────────────
locals {
  # length
  subnet_count  = length(var.subnets)

  # flatten
  all_subnets   = flatten([var.private_subnets, var.public_subnets])

  # distinct — eliminar duplicados
  unique_azs    = distinct(var.availability_zones)

  # sort
  sorted_names  = sort(var.names)

  # merge — combinar mapas (el último sobreescribe)
  merged_tags   = merge(local.common_tags, var.extra_tags)

  # lookup — acceder a un mapa con default
  instance_type = lookup(var.instance_types, var.environment, "t3.micro")

  # element — acceder a elemento de lista por índice (circular)
  az = element(var.azs, count.index)

  # toset, tolist, tomap — convertir tipos
  az_set        = toset(var.availability_zones)

  # contains
  is_prod       = contains(["prod", "production"], var.environment)

  # index — encontrar la posición de un elemento
  az_index      = index(var.azs, "us-east-1a")

  # zipmap — crear mapa desde dos listas paralelas
  az_to_subnet  = zipmap(var.azs, var.subnet_ids)

  # setintersection, setunion, setsubtract
  common_ports  = setintersection(toset(var.allowed_ports), toset(var.required_ports))
}

# ── Numeric Functions ─────────────────────────────────────────────────
locals {
  # max, min
  max_instances = max(var.min_instances, 2)
  storage_gb    = min(var.requested_storage, 1000)  # cap en 1TB

  # ceil, floor
  nodes_needed  = ceil(var.workload / var.node_capacity)

  # abs
  diff          = abs(var.target - var.current)

  # pow
  storage_bytes = pow(2, 30)  # 1 GiB en bytes
}

# ── Filesystem Functions ─────────────────────────────────────────────
locals {
  # file — leer archivo como string
  init_script   = file("${path.module}/scripts/init.sh")

  # filebase64 — leer archivo en base64 (para user_data)
  user_data     = filebase64("${path.module}/scripts/user_data.sh")

  # filemd5 — hash del archivo (forzar re-deploy cuando cambia)
  script_hash   = filemd5("${path.module}/scripts/app.sh")

  # path.module — directorio del módulo actual
  # path.root   — directorio del módulo raíz
  # path.cwd    — directorio de trabajo actual
}
```

---

## Data Sources — Leer Infraestructura Existente

```hcl
# Leer datos de AWS sin crear recursos

# AMI más reciente de Amazon Linux
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# VPC existente por nombre
data "aws_vpc" "existing" {
  filter {
    name   = "tag:Name"
    values = ["${var.project}-${var.environment}-vpc"]
  }
}

# Availability Zones disponibles en la región
data "aws_availability_zones" "available" {
  state = "available"
  # Excluir zonas locales
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

# Cuenta de AWS actual
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Outputs del state remoto de otro módulo
data "terraform_remote_state" "vpc" {
  backend = "s3"
  config = {
    bucket = "mi-empresa-terraform-state"
    key    = "${var.environment}/us-east-1/vpc/terraform.tfstate"
    region = "us-east-1"
  }
}

# Uso del remote state
resource "aws_instance" "app" {
  subnet_id = data.terraform_remote_state.vpc.outputs.private_subnet_ids[0]
}

# SSM Parameter Store
data "aws_ssm_parameter" "db_password" {
  name            = "/app/${var.environment}/db_password"
  with_decryption = true
}

# Secrets Manager
data "aws_secretsmanager_secret_version" "app_secrets" {
  secret_id = "/${var.environment}/app/secrets"
}

locals {
  app_secrets = jsondecode(data.aws_secretsmanager_secret_version.app_secrets.secret_string)
}
```
