# Providers — Configuración y Patrones Multi-Cloud

## Configuración de Providers — Versioning y Autenticación

```hcl
# versions.tf — siempre en el root module
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"   # ~> significa >= 5.0 y < 6.0 (solo minor/patch updates)
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}

# Operadores de versión:
# = 1.0.0     → exactamente esa versión
# != 1.0.0    → cualquier versión excepto esa
# > 1.0.0     → mayor que
# >= 1.0.0    → mayor o igual
# < 2.0.0     → menor que
# ~> 1.0.0    → >= 1.0.0 y < 1.1.0 (patch updates solo)
# ~> 1.0      → >= 1.0 y < 2.0 (minor + patch updates)
```

---

## AWS Provider — Configuración Completa

```hcl
# provider.tf
provider "aws" {
  region = var.aws_region

  # Default tags — aplican a TODOS los recursos gestionados por este provider
  default_tags {
    tags = {
      Project     = var.project
      Environment = var.environment
      ManagedBy   = "terraform"
      Owner       = var.team
    }
  }
}

# Autenticación (en orden de precedencia que usa el provider):
# 1. Variables de entorno: AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY
# 2. Archivo ~/.aws/credentials
# 3. IAM Role del EC2 instance / ECS task / Lambda
# 4. OIDC para GitHub Actions (más seguro que access keys)

# Provider con perfil específico
provider "aws" {
  profile = "my-profile"  # usar perfil del ~/.aws/config
  region  = "us-east-1"
}

# Provider asumiendo un rol (cross-account)
provider "aws" {
  region = "us-east-1"

  assume_role {
    role_arn     = "arn:aws:iam::PROD_ACCOUNT_ID:role/TerraformRole"
    session_name = "terraform-session"
    external_id  = var.external_id  # para mayor seguridad
  }
}

# ── Provider con alias — múltiples regiones o cuentas ─────────────────
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

provider "aws" {
  alias  = "eu_west_1"
  region = "eu-west-1"
}

provider "aws" {
  alias  = "prod_account"
  region = "us-east-1"
  assume_role {
    role_arn = "arn:aws:iam::PROD_ACCOUNT:role/TerraformRole"
  }
}

# Usar el provider con alias en un recurso
resource "aws_s3_bucket" "eu_backup" {
  provider = aws.eu_west_1
  bucket   = "myapp-eu-backup"
}

# Pasar provider a un módulo
module "vpc_eu" {
  source = "./modules/vpc"

  providers = {
    aws = aws.eu_west_1  # el módulo usará el provider eu_west_1
  }

  # variables del módulo...
}
```

---

## GCP Provider

```hcl
provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone

  # Autenticación:
  # 1. GOOGLE_APPLICATION_CREDENTIALS env var (path al JSON del SA)
  # 2. gcloud auth application-default login
  # 3. Service account key (no recomendado para producción)
  # credentials = file("service-account.json")  # solo para dev/CI local
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
}

# Múltiples proyectos
provider "google" {
  alias   = "logging_project"
  project = "my-logging-project"
  region  = "us-central1"
}
```

---

## Azure Provider

```hcl
provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = true  # protección extra
    }
    key_vault {
      purge_soft_delete_on_destroy = false  # mantener los secretos en la papelera
      recover_soft_deleted_key_vaults = true
    }
  }

  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id

  # Autenticación:
  # 1. Service Principal con Client Secret
  # client_id     = var.client_id
  # client_secret = var.client_secret
  # 2. Service Principal con Certificado
  # 3. Managed Identity (recomendado para CI/CD en Azure)
  # 4. Azure CLI local
}
```

---

## Kubernetes Provider

```hcl
# Usando las credenciales del cluster EKS creado por Terraform
data "aws_eks_cluster" "main" {
  name = module.eks.cluster_name
}

data "aws_eks_cluster_auth" "main" {
  name = module.eks.cluster_name
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.main.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.main.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.main.token
}

provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.main.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.main.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.main.token
  }
}

# Instalar Helm charts con el provider de Helm
resource "helm_release" "ingress_nginx" {
  name             = "ingress-nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  version          = "4.8.3"
  namespace        = "ingress-nginx"
  create_namespace = true

  set {
    name  = "controller.service.type"
    value = "LoadBalancer"
  }

  set {
    name  = "controller.replicaCount"
    value = "2"
  }

  values = [
    yamlencode({
      controller = {
        resources = {
          requests = { cpu = "100m", memory = "90Mi" }
          limits   = { cpu = "200m", memory = "180Mi" }
        }
      }
    })
  ]

  depends_on = [module.eks]
}
```

---

## Provider Lock File — .terraform.lock.hcl

```hcl
# .terraform.lock.hcl — generado por terraform init
# COMMITEAR este archivo para reproducibilidad

provider "registry.terraform.io/hashicorp/aws" {
  version     = "5.31.0"
  constraints = "~> 5.0"
  hashes = [
    "h1:...",
    # hashes para múltiples plataformas (linux, darwin, windows)
  ]
}

# Actualizar los providers a las últimas versiones permitidas
terraform init -upgrade
# Esto actualiza el .terraform.lock.hcl con las nuevas versiones

# Regenerar hashes para todas las plataformas (para CI en Linux con dev en Mac)
terraform providers lock \
  -platform=linux_amd64 \
  -platform=linux_arm64 \
  -platform=darwin_amd64 \
  -platform=darwin_arm64 \
  -platform=windows_amd64
```

---

## Null Provider y terraform_data

```hcl
# null_resource — ejecutar scripts locales o como triggers
resource "null_resource" "run_migration" {
  # Trigger cuando el ID de la base de datos cambia
  triggers = {
    db_id = aws_db_instance.main.id
  }

  provisioner "local-exec" {
    command = "python scripts/run_migrations.py --db-url ${aws_db_instance.main.endpoint}"
  }
}

# terraform_data — alternativa moderna a null_resource (TF 1.4+)
resource "terraform_data" "run_migration" {
  triggers_replace = [
    aws_db_instance.main.id,
    aws_db_instance.main.address,
  ]

  provisioner "local-exec" {
    command = "python scripts/run_migrations.py"
    environment = {
      DB_URL = aws_db_instance.main.endpoint
    }
  }
}

# random provider — generar valores únicos
resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

resource "aws_s3_bucket" "artifacts" {
  bucket = "myapp-artifacts-${random_string.suffix.result}"
  # → "myapp-artifacts-a1b2c3d4"
}

resource "random_password" "db_password" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id     = aws_secretsmanager_secret.db_password.id
  secret_string = random_password.db_password.result
}
```
