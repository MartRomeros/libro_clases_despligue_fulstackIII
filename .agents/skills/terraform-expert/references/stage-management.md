# Gestión del Estado — Backends, Locking y Manipulación

## Backend Remoto — Configuración por Proveedor

### AWS S3 + DynamoDB (el más usado)

```hcl
# backend.tf — configuración del backend remoto
terraform {
  backend "s3" {
    bucket         = "mi-empresa-terraform-state"
    key            = "prod/us-east-1/vpc/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    kms_key_id     = "arn:aws:kms:us-east-1:123456789:key/abc-123"
    dynamodb_table = "terraform-state-lock"

    # Para asumir un rol específico (cross-account)
    role_arn     = "arn:aws:iam::123456789:role/TerraformStateRole"
    session_name = "terraform-prod"

    # Workspace prefix (cuando se usan workspaces)
    workspace_key_prefix = "workspaces"
  }
}

# Crear el bucket y la tabla DynamoDB para el backend
resource "aws_s3_bucket" "terraform_state" {
  bucket = "mi-empresa-terraform-state"

  lifecycle {
    prevent_destroy = true  # NUNCA destruir el bucket de state
  }
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.terraform_state.arn
    }
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_dynamodb_table" "terraform_locks" {
  name         = "terraform-state-lock"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  lifecycle {
    prevent_destroy = true
  }
}
```

### GCP — Google Cloud Storage

```hcl
terraform {
  backend "gcs" {
    bucket      = "mi-empresa-terraform-state"
    prefix      = "prod/us-central1/gke-cluster"
    credentials = "path/to/credentials.json"  # o usar GOOGLE_CREDENTIALS env var
  }
}
```

### Azure Blob Storage

```hcl
terraform {
  backend "azurerm" {
    resource_group_name  = "terraform-state-rg"
    storage_account_name = "terraformstateaccount"
    container_name       = "tfstate"
    key                  = "prod/eastus/aks/terraform.tfstate"
  }
}
```

### Terraform Cloud

```hcl
terraform {
  cloud {
    organization = "mi-empresa"
    workspaces {
      name = "prod-us-east-1-vpc"
    }
  }
}
```

---

## Inicialización con Variables de Backend

```bash
# Pasar configuración del backend por variables (útil en CI/CD)
terraform init \
  -backend-config="bucket=mi-empresa-terraform-state" \
  -backend-config="key=prod/vpc/terraform.tfstate" \
  -backend-config="region=us-east-1"

# O usar un archivo de configuración del backend
terraform init -backend-config=backend-prod.hcl

# backend-prod.hcl
bucket         = "mi-empresa-terraform-state"
key            = "prod/vpc/terraform.tfstate"
region         = "us-east-1"
encrypt        = true
dynamodb_table = "terraform-state-lock"
```

---

## Workspaces — Entornos con el Mismo Código

```bash
# Ver workspace actual
terraform workspace show

# Listar workspaces
terraform workspace list

# Crear y cambiar a un workspace
terraform workspace new staging
terraform workspace new prod

# Cambiar de workspace
terraform workspace select prod

# Eliminar workspace
terraform workspace delete staging  # solo si está vacío (destruido)

# Usar el workspace en el código
resource "aws_s3_bucket" "app" {
  bucket = "myapp-${terraform.workspace}-artifacts"
  # → "myapp-prod-artifacts" o "myapp-staging-artifacts"
}

# Lógica condicional basada en workspace
locals {
  is_prod     = terraform.workspace == "prod"
  environment = terraform.workspace

  instance_type = local.is_prod ? "t3.large" : "t3.micro"
  min_instances = local.is_prod ? 3 : 1
}
```

**Cuándo usar workspaces vs directorios separados:**
- Workspaces: infraestructura idéntica, diferente configuración (staging vs prod)
- Directorios: infraestructura diferente por entorno o cuando el riesgo de blast radius es alto

---

## Manipulación del State — Con Precaución

```bash
# ── SIEMPRE hacer backup antes de manipular el state ─────────────────
terraform state pull > backup_$(date +%Y%m%d_%H%M%S).tfstate

# ── Listar recursos ───────────────────────────────────────────────────
terraform state list
terraform state list | grep aws_instance  # filtrar por tipo
terraform state list module.vpc           # recursos de un módulo

# ── Ver detalles de un recurso ────────────────────────────────────────
terraform state show aws_vpc.main
terraform state show 'module.vpc.aws_vpc.this'

# ── Mover recursos (renombrar sin destruir y recrear) ─────────────────
# Caso: renombrar un recurso en el código
# Antes: resource "aws_instance" "web"
# Después: resource "aws_instance" "web_server"
terraform state mv aws_instance.web aws_instance.web_server

# Mover recurso a un módulo
terraform state mv aws_vpc.main module.networking.aws_vpc.this

# Mover módulo a otro módulo
terraform state mv module.old_vpc module.networking.module.vpc

# ── Eliminar del state sin destruir (dejar el recurso huérfano) ───────
# Caso: quieres que Terraform deje de gestionar ese recurso
terraform state rm aws_instance.legacy
# El recurso sigue existiendo en AWS pero Terraform no lo conoce

# ── Importar recursos existentes (el inverso del state rm) ────────────
# Caso: recurso existente que Terraform no creó
# Paso 1: escribir el bloque resource en el código
resource "aws_instance" "existing" {
  ami           = "ami-12345678"
  instance_type = "t3.micro"
  # ... otros atributos
}
# Paso 2: importar
terraform import aws_instance.existing i-1234567890abcdef0

# Importar recursos de un módulo
terraform import 'module.vpc.aws_subnet.private[0]' subnet-12345678

# ── Forzar recreación de un recurso ──────────────────────────────────
# Moderno (Terraform 1.2+):
terraform apply -replace=aws_instance.web

# Deprecated (antes de 1.2):
terraform taint aws_instance.web
terraform apply
```

---

## Import Blocks — Importación Declarativa (TF 1.5+)

```hcl
# El nuevo estilo de importación — declarativo y revisable en el plan
import {
  id = "i-1234567890abcdef0"
  to = aws_instance.existing
}

resource "aws_instance" "existing" {
  ami           = "ami-12345678"
  instance_type = "t3.micro"
  # ...
}

# Importar recursos de un módulo
import {
  id = "subnet-12345678"
  to = module.vpc.aws_subnet.private[0]
}

# Múltiples imports en el mismo apply
import {
  id = "vpc-12345678"
  to = aws_vpc.main
}

import {
  id = "igw-12345678"
  to = aws_internet_gateway.main
}

# Generar configuración automáticamente desde el recurso existente
terraform plan -generate-config-out=generated.tf
# Terraform genera el bloque resource con todos los atributos del recurso existente
# Revisar y limpiar el archivo generado antes de usar en producción
```

---

## Moved Blocks — Refactorizar sin Destruir (TF 1.1+)

```hcl
# Caso: renombrar un recurso en el código
# Antes en el código: resource "aws_instance" "web" { ... }
# Después en el código: resource "aws_instance" "application_server" { ... }

moved {
  from = aws_instance.web
  to   = aws_instance.application_server
}

# Mover a un módulo
moved {
  from = aws_vpc.main
  to   = module.networking.aws_vpc.this
}

# Mover de count a for_each
# Antes: resource "aws_subnet" "private" con count = 3
# Después: resource "aws_subnet" "private" con for_each

moved {
  from = aws_subnet.private[0]
  to   = aws_subnet.private["us-east-1a"]
}

moved {
  from = aws_subnet.private[1]
  to   = aws_subnet.private["us-east-1b"]
}

moved {
  from = aws_subnet.private[2]
  to   = aws_subnet.private["us-east-1c"]
}

# ✅ Los moved blocks se pueden eliminar del código después de que todos
# hayan ejecutado el apply con el moved block.
# El moved block SOLO corre una vez (si ya está en el state, no hace nada)
```

---

## Recuperación de Estado Corrupto

```bash
# El state está corrupto o inconsistente con la realidad

# Paso 1: no entrar en pánico — hacer backup
cp .terraform/terraform.tfstate .terraform/terraform.tfstate.backup

# Paso 2: verificar el estado actual
terraform state list   # si esto falla, el state está realmente dañado

# Paso 3: obtener el state desde el backend
terraform state pull > recovered.tfstate

# Paso 4: si el backend tiene versiones anteriores (S3 con versioning)
aws s3api list-object-versions --bucket my-state-bucket --prefix "prod/vpc/terraform.tfstate"
# Recuperar versión anterior:
aws s3api get-object \
  --bucket my-state-bucket \
  --key "prod/vpc/terraform.tfstate" \
  --version-id "ABCDEFG" \
  terraform.tfstate.recovered

# Paso 5: hacer plan para ver el delta
terraform plan  # Terraform mostrará qué cree que necesita cambiar

# Paso 6: si el plan tiene destrucciones incorrectas → importar los recursos manualmente
```
