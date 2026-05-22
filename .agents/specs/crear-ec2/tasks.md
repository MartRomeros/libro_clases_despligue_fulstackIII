# Tasks: Crear instancias EC2

## Task 1: Mejorar contrato del modulo EC2
- Objetivo: permitir instancias Ubuntu publicas y privadas con volumen raiz configurable.
- Archivos esperados: `modules/ec2/ec2.tf`, `modules/ec2/variables.tf`, `modules/ec2/outputs.tf`.
- Tests requeridos: `terraform fmt -recursive`, `terraform validate`.
- Criterio de finalizacion: el modulo instala Git/Docker, usa usuario `ubuntu`, permite `security_group_ids`, `associate_public_ip_address` y volumen `gp3` de al menos 20 GiB.

## Task 2: Ajustar security group publico
- Objetivo: permitir SSH, HTTP y HTTPS para `ec2-bastion` y `ec2-api-gw`.
- Archivos esperados: `modules/security_groups/sg_bastion/main.tf`, `variables.tf` si se parametriza CIDR.
- Tests requeridos: `terraform validate`, revision de `terraform plan`.
- Criterio de finalizacion: el security group publico permite `22`, `80` y `443` desde CIDR configurado.

## Task 3: Ajustar security group backend
- Objetivo: permitir acceso desde el security group publico hacia microservicios.
- Archivos esperados: `modules/security_groups/sg_backend/main.tf`, `modules/security_groups/sg_backend/variables.tf`.
- Tests requeridos: `terraform validate`, revision de `terraform plan`.
- Criterio de finalizacion: `sg_backend` permite `22`, `3000`, `3001`, `3002` y `8080` solo desde el security group publico.

## Task 4: Declarar las 6 instancias EC2
- Objetivo: crear `ec2-bastion`, `ec2-api-gw`, `ec2-ms-auth`, `ec2-ms-asistencia`, `ec2-ms-gestion` y `ec2-ms-comunicaciones`.
- Archivos esperados: `main.tf`, `variables.tf`.
- Tests requeridos: `terraform validate`, revision de `terraform plan`.
- Criterio de finalizacion: 2 instancias publicas y 4 privadas usan la AMI Ubuntu, `t3.micro`, el mismo key pair y los security groups correctos.

## Task 5: Crear outputs operativos
- Objetivo: mostrar direcciones, URL del API Gateway y comandos SSH.
- Archivos esperados: `outputs.tf`.
- Tests requeridos: `terraform validate`, `terraform output` despues de apply aprobado.
- Criterio de finalizacion: existen outputs claros para acceder a `ec2-bastion`, `ec2-api-gw` y microservicios via jump host.

## Task 6: Validacion final
- Objetivo: confirmar que la infraestructura planificada coincide con la spec.
- Archivos esperados: todos los Terraform modificados.
- Tests requeridos: `terraform fmt -recursive`, `terraform validate`, `terraform plan`.
- Criterio de finalizacion: el plan muestra los recursos esperados sin cambios fuera de alcance.
