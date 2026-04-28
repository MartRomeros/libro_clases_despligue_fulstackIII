# Patrones Avanzados — Loops, Dinámico y Lifecycle

## count vs for_each — Cuándo Usar Cada Uno

```hcl
# ── COUNT: para recursos IDÉNTICOS ───────────────────────────────────
# Usar cuando todos los recursos son exactamente iguales
# El problema: si eliminas el elemento [1] de 3, Terraform DESTRUYE y RECREA [2]
resource "aws_instance" "web" {
  count = 3

  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro"

  tags = {
    Name  = "web-server-${count.index + 1}"
    Index = count.index
  }
}

# Acceder a recursos con count:
aws_instance.web[0].id
aws_instance.web[*].id  # lista de todos los IDs

# ── FOR_EACH: para recursos con IDENTIDAD ÚNICA ──────────────────────
# Usar cuando cada recurso tiene una clave única y estable
# El beneficio: eliminar una entrada solo afecta a ESE recurso
resource "aws_subnet" "private" {
  for_each = {
    "us-east-1a" = "10.0.1.0/24"
    "us-east-1b" = "10.0.2.0/24"
    "us-east-1c" = "10.0.3.0/24"
  }

  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value
  availability_zone = each.key

  tags = {
    Name = "private-${each.key}"
  }
}

# Acceder a recursos con for_each:
aws_subnet.private["us-east-1a"].id
values(aws_subnet.private)[*].id  # lista de todos los IDs

# for_each con una lista (convertir a set o mapa primero)
variable "environment_names" {
  type    = list(string)
  default = ["dev", "staging", "prod"]
}

resource "aws_iam_role" "environment" {
  for_each = toset(var.environment_names)  # list → set para for_each

  name = "role-${each.key}"
  # each.key == each.value para sets
}

# for_each con lista de objetos — crear un mapa primero
variable "users" {
  type = list(object({
    name  = string
    email = string
    role  = string
  }))
}

resource "aws_iam_user" "this" {
  for_each = { for user in var.users : user.name => user }

  name = each.key
  tags = {
    Email = each.value.email
    Role  = each.value.role
  }
}
```

---

## Dynamic Blocks — Bloques Opcionales y Repetitivos

```hcl
# Sin dynamic — repetitivo y poco flexible
resource "aws_security_group" "web" {
  name = "web-sg"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Con dynamic — flexible y reutilizable
variable "ingress_rules" {
  type = list(object({
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
    description = optional(string, "")
  }))
  default = [
    { from_port = 80, to_port = 80, protocol = "tcp", cidr_blocks = ["0.0.0.0/0"] },
    { from_port = 443, to_port = 443, protocol = "tcp", cidr_blocks = ["0.0.0.0/0"] },
  ]
}

resource "aws_security_group" "web" {
  name = "web-sg"

  dynamic "ingress" {
    for_each = var.ingress_rules
    content {
      from_port   = ingress.value.from_port
      to_port     = ingress.value.to_port
      protocol    = ingress.value.protocol
      cidr_blocks = ingress.value.cidr_blocks
      description = ingress.value.description
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Dynamic block condicional — el bloque se incluye o no según una condición
resource "aws_db_instance" "main" {
  identifier     = "myapp-db"
  instance_class = "db.t3.medium"

  # Incluir el bloque restore_to_point_in_time solo si se proporciona
  dynamic "restore_to_point_in_time" {
    for_each = var.restore_from_snapshot != null ? [1] : []
    content {
      source_db_instance_identifier  = var.restore_from_snapshot
      restore_time                    = var.restore_time
      use_latest_restorable_time      = var.restore_time == null
    }
  }
}

# Dynamic con for_each y objetos complejos
resource "aws_ecs_task_definition" "app" {
  family = "myapp"

  dynamic "volume" {
    for_each = var.volumes  # list(object({ name = string, host_path = string }))
    content {
      name      = volume.value.name
      host_path = volume.value.host_path
    }
  }
}
```

---

## Lifecycle Rules — Controlar el Comportamiento de Terraform

```hcl
resource "aws_instance" "web" {
  ami           = data.aws_ami.latest.id
  instance_type = "t3.medium"

  lifecycle {
    # Crear el recurso nuevo ANTES de destruir el antiguo
    # Útil para: instancias detrás de un load balancer, recursos sin tiempo de inactividad
    create_before_destroy = true

    # Nunca destruir este recurso — terraform destroy fallará
    # Útil para: bases de datos de producción, buckets críticos
    prevent_destroy = true

    # Ignorar cambios en estos atributos después de la creación inicial
    # Útil cuando: el atributo lo modifica un proceso externo (auto-scaling, scripts)
    ignore_changes = [
      ami,                    # actualizar la AMI no forzará reemplazo
      user_data,              # cambios en user_data no recrean la instancia
      tags["LastUpdated"],    # tag específico gestionado externamente
    ]

    # Condición de precondición — verificar antes de crear/actualizar
    precondition {
      condition     = var.instance_count >= 2 || var.environment != "prod"
      error_message = "Production environment requires at least 2 instances for HA."
    }

    # Condición de postcondición — verificar después de crear
    postcondition {
      condition     = self.public_ip != ""
      error_message = "Instance must have a public IP."
    }
  }
}

# ── create_before_destroy en práctica ────────────────────────────────
resource "aws_launch_template" "app" {
  name_prefix   = "app-"
  image_id      = data.aws_ami.app.id
  instance_type = "t3.medium"

  lifecycle {
    create_before_destroy = true
    # Cuando la AMI cambie: crear el nuevo launch template → actualizar el ASG
    # → terminar las instancias con la vieja AMI gradualmente
  }
}

# ── ignore_changes en casos reales ───────────────────────────────────
resource "aws_autoscaling_group" "app" {
  name = "app-asg"

  lifecycle {
    ignore_changes = [
      desired_capacity,  # gestionado por auto-scaling policies, no por Terraform
    ]
  }
}

resource "helm_release" "app" {
  name  = "my-app"
  chart = "my-app"

  lifecycle {
    ignore_changes = [
      version,           # actualizado por el pipeline de CD, no por Terraform
      values,            # configuración gestionada por otro sistema
    ]
  }
}
```

---

## Check Blocks — Validaciones Continuas (TF 1.5+)

```hcl
# check blocks verifican condiciones en cada plan y apply
# No bloquean el apply (a diferencia de precondition/postcondition)
# Son advertencias que alertan sobre configuración incorrecta

check "security_groups_not_open" {
  data "aws_security_group" "web" {
    id = aws_security_group.web.id
  }

  assert {
    condition     = !contains(data.aws_security_group.web.ingress[*].cidr_blocks, ["0.0.0.0/0"])
    error_message = "WARNING: Security group has unrestricted ingress. Review the rules."
  }
}

check "ssl_certificate_not_expiring" {
  data "aws_acm_certificate" "main" {
    domain      = var.domain_name
    most_recent = true
  }

  assert {
    condition     = timecmp(data.aws_acm_certificate.main.not_after, timeadd(timestamp(), "720h")) > 0
    error_message = "SSL certificate expires within 30 days. Renew immediately."
  }
}
```

---

## Flatten y Zipmap — Transformaciones Complejas

```hcl
# Problema: tienes una variable con múltiples listas anidadas
variable "services" {
  type = map(object({
    name  = string
    ports = list(number)
  }))
  default = {
    web = { name = "web", ports = [80, 443] }
    api = { name = "api", ports = [8080, 8443] }
  }
}

# Quieres crear una regla de security group por cada combinación servicio+puerto
locals {
  # Crear lista plana de todas las combinaciones
  all_service_ports = flatten([
    for service_name, service in var.services : [
      for port in service.ports : {
        service = service_name
        name    = service.name
        port    = port
      }
    ]
  ])

  # Convertir a mapa para usar con for_each
  service_port_map = {
    for item in local.all_service_ports :
    "${item.service}-${item.port}" => item
  }
}

resource "aws_security_group_rule" "service_ports" {
  for_each = local.service_port_map

  type        = "ingress"
  from_port   = each.value.port
  to_port     = each.value.port
  protocol    = "tcp"
  cidr_blocks = ["10.0.0.0/8"]
  description = "${each.value.name} on port ${each.value.port}"

  security_group_id = aws_security_group.app.id
}

# Resultado: reglas para web-80, web-443, api-8080, api-8443
```

---

## depends_on — Dependencias Explícitas

```hcl
# Terraform infiere dependencias automáticamente cuando un recurso referencia a otro
# depends_on se usa solo cuando la dependencia NO es obvia para Terraform

# Caso típico: recurso que depende de los permisos de otro recurso
resource "aws_iam_role_policy_attachment" "lambda_exec" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_function" "app" {
  filename      = "app.zip"
  function_name = "my-app"
  role          = aws_iam_role.lambda.arn

  # La función necesita el rol Y su policy attachment para funcionar
  # Terraform no sabe esto automáticamente (no hay referencia directa)
  depends_on = [aws_iam_role_policy_attachment.lambda_exec]
}

# depends_on en módulos (TF 1.1+)
module "app" {
  source = "./modules/app"

  depends_on = [module.database]  # esperar a que la DB esté lista
}
```
