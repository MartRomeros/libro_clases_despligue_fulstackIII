# Testing y CI/CD — Validación, Testing y Automatización

## Pipeline de CI/CD para Terraform — GitHub Actions

```yaml
# .github/workflows/terraform.yml
name: Terraform

on:
  push:
    branches: [main]
    paths: ['infrastructure/**']
  pull_request:
    branches: [main]
    paths: ['infrastructure/**']

permissions:
  id-token: write    # para OIDC con AWS
  contents: read
  pull-requests: write

env:
  TF_VERSION: '1.6.4'
  TF_WORKING_DIR: 'infrastructure/environments/prod'

jobs:
  validate:
    name: Validate
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: ${{ env.TF_VERSION }}

      - name: Terraform Format Check
        run: terraform fmt -check -recursive
        working-directory: infrastructure/

      - name: Terraform Init
        run: terraform init -backend=false
        working-directory: ${{ env.TF_WORKING_DIR }}

      - name: Terraform Validate
        run: terraform validate
        working-directory: ${{ env.TF_WORKING_DIR }}

      - name: TFLint
        uses: terraform-linters/setup-tflint@v4
        with:
          tflint_version: v0.50.0

      - run: tflint --init
        working-directory: ${{ env.TF_WORKING_DIR }}

      - run: tflint --recursive
        working-directory: ${{ env.TF_WORKING_DIR }}

      - name: Security Scan with Checkov
        uses: bridgecrewio/checkov-action@master
        with:
          directory: infrastructure/
          framework: terraform
          soft_fail: false
          output_format: sarif
          output_file_path: checkov-results.sarif

      - name: Upload Checkov results
        uses: github/codeql-action/upload-sarif@v3
        if: always()
        with:
          sarif_file: checkov-results.sarif

  plan:
    name: Plan
    runs-on: ubuntu-latest
    needs: validate
    if: github.event_name == 'pull_request'

    steps:
      - uses: actions/checkout@v4

      - name: Configure AWS Credentials (OIDC — sin access keys estáticos)
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::${{ vars.AWS_ACCOUNT_ID }}:role/GitHubActionsRole
          aws-region: us-east-1

      - uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: ${{ env.TF_VERSION }}

      - name: Terraform Init
        run: terraform init
        working-directory: ${{ env.TF_WORKING_DIR }}

      - name: Terraform Plan
        id: plan
        run: |
          terraform plan -out=tfplan -no-color 2>&1 | tee plan_output.txt
          echo "exitcode=${PIPESTATUS[0]}" >> "$GITHUB_OUTPUT"
        working-directory: ${{ env.TF_WORKING_DIR }}
        continue-on-error: true

      # Publicar el plan como comentario en el PR
      - name: Comment Plan on PR
        uses: actions/github-script@v7
        with:
          github-token: ${{ secrets.GITHUB_TOKEN }}
          script: |
            const fs = require('fs');
            const plan = fs.readFileSync('${{ env.TF_WORKING_DIR }}/plan_output.txt', 'utf8');
            const truncated = plan.length > 65000 ? plan.slice(0, 65000) + '\n...(truncated)' : plan;

            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: `## Terraform Plan\n\`\`\`\n${truncated}\n\`\`\``
            });

      - name: Fail if plan failed
        if: steps.plan.outputs.exitcode == '1'
        run: exit 1

      # Guardar el plan como artifact para usarlo en apply
      - uses: actions/upload-artifact@v4
        with:
          name: tfplan
          path: ${{ env.TF_WORKING_DIR }}/tfplan
          retention-days: 1

  apply:
    name: Apply
    runs-on: ubuntu-latest
    needs: plan
    if: github.ref == 'refs/heads/main' && github.event_name == 'push'
    environment:
      name: production   # requiere aprobación manual en GitHub Environments

    steps:
      - uses: actions/checkout@v4

      - name: Configure AWS Credentials (OIDC)
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::${{ vars.AWS_ACCOUNT_ID }}:role/GitHubActionsRole
          aws-region: us-east-1

      - uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: ${{ env.TF_VERSION }}

      - name: Terraform Init
        run: terraform init
        working-directory: ${{ env.TF_WORKING_DIR }}

      - name: Terraform Apply
        run: terraform apply -auto-approve tfplan
        working-directory: ${{ env.TF_WORKING_DIR }}
```

---

## Herramientas de Validación y Linting

### TFLint — Linting Específico de Terraform

```bash
# Instalar: brew install tflint
# o: curl -s https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh | bash

# .tflint.hcl
config {
  format = "compact"
  module = true
  force  = false
}

plugin "aws" {
  enabled = true
  version = "0.29.0"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}

rule "terraform_deprecated_interpolation" {
  enabled = true
}

rule "terraform_unused_declarations" {
  enabled = true
}

rule "terraform_comment_syntax" {
  enabled = true
}

rule "terraform_documented_outputs" {
  enabled = true
}

rule "terraform_documented_variables" {
  enabled = true
}

rule "terraform_typed_variables" {
  enabled = true
}

rule "terraform_module_pinned_source" {
  enabled = true
  style   = "semver"  # forzar versioning semántico en módulos
}

# Correr tflint
tflint --init
tflint
tflint --recursive  # revisar todos los módulos
```

### Checkov — Seguridad y Compliance

```bash
# Instalar: pip install checkov
# o: brew install checkov

# Escanear todo el directorio
checkov -d infrastructure/

# Escanear con framework específico
checkov -d infrastructure/ --framework terraform

# Ignorar checks específicos (documentar el motivo)
checkov -d infrastructure/ --skip-check CKV_AWS_20,CKV_AWS_57

# En el código HCL — ignorar un check específico con comentario
resource "aws_s3_bucket" "public_website" {
  bucket = "my-public-website"
  # checkov:skip=CKV_AWS_20:Public website bucket intentionally allows public access
  # checkov:skip=CKV2_AWS_6:Public ACL required for static website hosting
}

# Generar reporte SARIF para GitHub Security
checkov -d infrastructure/ --output sarif > checkov.sarif
```

### terraform-docs — Documentación Automática

```bash
# Instalar: brew install terraform-docs

# Generar documentación en README.md
terraform-docs markdown table --output-file README.md .

# Configuración en .terraform-docs.yml
formatter: "markdown table"

output:
  file: "README.md"
  mode: inject
  template: |-
    <!-- BEGIN_TF_DOCS -->
    {{ .Content }}
    <!-- END_TF_DOCS -->

sections:
  show:
    - inputs
    - outputs
    - requirements
    - providers
    - modules

sort:
  enabled: true
  by: name
```

---

## Terratest — Testing de Infraestructura con Go

```go
// test/vpc_test.go
package test

import (
    "testing"
    "github.com/gruntwork-io/terratest/modules/terraform"
    "github.com/gruntwork-io/terratest/modules/aws"
    "github.com/stretchr/testify/assert"
    "github.com/stretchr/testify/require"
)

func TestVPCModule(t *testing.T) {
    t.Parallel()  // correr tests en paralelo para reducir tiempo

    awsRegion := "us-east-1"

    terraformOptions := &terraform.Options{
        TerraformDir: "../modules/vpc",
        Vars: map[string]interface{}{
            "name":                  "test-vpc",
            "cidr_block":            "10.99.0.0/16",
            "availability_zones":    []string{"us-east-1a", "us-east-1b"},
            "private_subnet_cidrs":  []string{"10.99.1.0/24", "10.99.2.0/24"},
            "public_subnet_cidrs":   []string{"10.99.101.0/24", "10.99.102.0/24"},
            "enable_nat_gateway":    true,
            "single_nat_gateway":    true,  // más barato para tests
        },
        // No reintentar en tests de integración para ver fallos rápido
        RetryableTerraformErrors: map[string]string{},
    }

    // Asegurar destrucción al final del test
    defer terraform.Destroy(t, terraformOptions)

    // Inicializar y aplicar
    terraform.InitAndApply(t, terraformOptions)

    // Obtener outputs
    vpcId           := terraform.Output(t, terraformOptions, "vpc_id")
    privateSubnetIds := terraform.OutputList(t, terraformOptions, "private_subnet_ids")
    publicSubnetIds  := terraform.OutputList(t, terraformOptions, "public_subnet_ids")

    // Verificar que el VPC existe y tiene la configuración correcta
    vpc := aws.GetVpcById(t, vpcId, awsRegion)
    require.NotNil(t, vpc)
    assert.Equal(t, "10.99.0.0/16", aws.GetTagValue(vpc.Tags, "CidrBlock"))

    // Verificar que se crearon las subnets correctas
    assert.Equal(t, 2, len(privateSubnetIds))
    assert.Equal(t, 2, len(publicSubnetIds))

    // Verificar que las subnets privadas no tienen ruta directa a internet
    for _, subnetId := range privateSubnetIds {
        routeTable := aws.GetRouteTableForSubnet(t, subnetId, awsRegion)
        // Verificar que la ruta por defecto apunta a un NAT Gateway, no a un IGW
        hasNatRoute := false
        for _, route := range routeTable.Routes {
            if aws.StringValue(route.DestinationCidrBlock) == "0.0.0.0/0" &&
               route.NatGatewayId != nil {
                hasNatRoute = true
                break
            }
        }
        assert.True(t, hasNatRoute, "Private subnet must route through NAT Gateway")
    }
}
```

---

## Terragrunt — DRY en Configuración de Múltiples Entornos

```hcl
# terragrunt.hcl (raíz del proyecto)
locals {
  account_vars = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  region_vars  = read_terragrunt_config(find_in_parent_folders("region.hcl"))
  env_vars     = read_terragrunt_config(find_in_parent_folders("env.hcl"))

  account_id  = local.account_vars.locals.account_id
  aws_region  = local.region_vars.locals.aws_region
  environment = local.env_vars.locals.environment
}

# Generar el provider automáticamente
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
provider "aws" {
  region = "${local.aws_region}"

  default_tags {
    tags = {
      Environment = "${local.environment}"
      ManagedBy   = "terragrunt"
    }
  }
}
EOF
}

# Backend remoto generado automáticamente — no repetir en cada módulo
remote_state {
  backend = "s3"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
  config = {
    bucket         = "mi-empresa-${local.account_id}-terraform-state"
    key            = "${path_relative_to_include()}/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}

# prod/us-east-1/vpc/terragrunt.hcl
terraform {
  source = "../../../../modules//vpc"
}

include "root" {
  path = find_in_parent_folders()
}

# Dependencias entre módulos de Terragrunt
dependency "vpc" {
  config_path = "../vpc"
  # Valor falso para cuando se corre plan sin la dependencia resuelta
  mock_outputs = {
    vpc_id             = "vpc-00000000000000000"
    private_subnet_ids = ["subnet-0000000000000000"]
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

inputs = {
  vpc_id          = dependency.vpc.outputs.vpc_id
  private_subnets = dependency.vpc.outputs.private_subnet_ids

  cluster_name = "myapp-prod"
  node_type    = "t3.large"
  min_nodes    = 3
  max_nodes    = 10
}
```

---

## OpenTofu — El Fork Open Source de Terraform

```bash
# OpenTofu es un fork open source de Terraform (antes de la licencia BSL)
# Completamente compatible con Terraform 1.5.x
# Instalar: brew install opentofu

# Los comandos son idénticos pero con 'tofu' en lugar de 'terraform'
tofu init
tofu plan
tofu apply
tofu destroy

# Diferencias clave de OpenTofu vs Terraform:
# 1. Licencia MPL 2.0 (open source vs BSL de HashiCorp)
# 2. State encryption nativa (TF necesita herramienta externa)
# 3. Provider/module mocking en tests (nativo)
# 4. Funciones provider-defined
# 5. Comunidad dirigida por CNCF

# State encryption en OpenTofu
terraform {
  encryption {
    key_provider "pbkdf2" "my_key" {
      passphrase = var.encryption_passphrase
    }

    method "aes_gcm" "default_encryption" {
      keys = key_provider.pbkdf2.my_key
    }

    state {
      method = method.aes_gcm.default_encryption
    }
  }
}
```
