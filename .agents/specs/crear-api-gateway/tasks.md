# Tasks: Crear API Gateway administrado por AWS

## Task 1: Crear estructura del módulo API Gateway
- **Objetivo:** Agregar un módulo local reutilizable para API Gateway sin conectarlo todavía al root module.
- **Archivos esperados:**
  - Crear `modules/api_gateway/main.tf`
  - Crear `modules/api_gateway/variables.tf`
  - Crear `modules/api_gateway/outputs.tf`
  - Crear `modules/api_gateway/README.md`
- **Tests requeridos:**
  - Ejecutar `terraform fmt -recursive`.
- **Criterio de finalización:**
  - El módulo existe con archivos separados para recursos, variables y outputs.
  - No se modifica aún `main.tf` del root module.

## Task 2: Definir contrato del módulo
- **Objetivo:** Declarar las variables y outputs necesarios para que el root module pueda crear el API Gateway apuntando a Nginx.
- **Archivos esperados:**
  - Modificar `modules/api_gateway/variables.tf`
  - Modificar `modules/api_gateway/outputs.tf`
- **Variables requeridas:**
  - `name`
  - `nginx_base_url`
  - `stage_name`
  - `cors_allowed_origins`
  - `tags`
- **Outputs requeridos:**
  - `api_id`
  - `api_endpoint`
  - `invoke_url`
  - `stage_name`
- **Tests requeridos:**
  - Ejecutar `terraform fmt -recursive`.
  - Ejecutar `terraform validate` después de conectar el módulo en una tarea posterior.
- **Criterio de finalización:**
  - Las variables tienen tipo, descripción y defaults razonables cuando aplica.
  - `nginx_base_url` valida o documenta que debe comenzar con `http://`.

## Task 3: Implementar HTTP API e integración HTTP proxy
- **Objetivo:** Crear el API Gateway HTTP API que termina HTTPS y reenvía tráfico HTTP a Nginx.
- **Archivos esperados:**
  - Modificar `modules/api_gateway/main.tf`
- **Recursos requeridos:**
  - `aws_apigatewayv2_api`
  - `aws_apigatewayv2_integration`
  - `aws_apigatewayv2_route` para `ANY /{proxy+}`
  - `aws_apigatewayv2_route` para `ANY /`
  - `aws_apigatewayv2_stage`
- **Configuración requerida:**
  - `protocol_type = "HTTP"`
  - `integration_type = "HTTP_PROXY"`
  - `integration_method = "ANY"`
  - `connection_type = "INTERNET"`
  - `auto_deploy = true`
- **Tests requeridos:**
  - Ejecutar `terraform fmt -recursive`.
- **Criterio de finalización:**
  - API Gateway preserva método y path hacia Nginx.
  - El stage queda disponible sin pasos manuales adicionales.

## Task 4: Conectar el módulo desde el root module
- **Objetivo:** Instanciar `modules/api_gateway` usando la EC2 `ec2-api-gw` como origen.
- **Archivos esperados:**
  - Modificar `main.tf`
- **Implementación esperada:**
  - Agregar `module "api_gateway"` después de `module "ec2_instances"`.
  - Pasar `nginx_base_url` usando `http://${module.ec2_instances["ec2-api-gw"].public_dns}`.
  - Usar fallback a `public_ip` solo si `public_dns` no funciona en AWS Academy.
- **Tests requeridos:**
  - Ejecutar `terraform fmt -recursive`.
  - Ejecutar `terraform validate`.
- **Criterio de finalización:**
  - El root module referencia el nuevo módulo sin ciclos de dependencias.
  - La integración apunta a Nginx por HTTP puerto `80`.

## Task 5: Actualizar outputs del root module
- **Objetivo:** Exponer la URL HTTPS que debe consumir el frontend.
- **Archivos esperados:**
  - Modificar `outputs.tf`
- **Cambios esperados:**
  - Cambiar `api_gateway_base_url` para que use `module.api_gateway.invoke_url`.
  - Agregar outputs auxiliares si aportan claridad, como `api_gateway_id` y `nginx_origin_url`.
- **Tests requeridos:**
  - Ejecutar `terraform fmt -recursive`.
  - Ejecutar `terraform validate`.
- **Criterio de finalización:**
  - El output principal entrega una URL HTTPS de AWS API Gateway.
  - Ya no se entrega como URL principal `http://<ip_ec2>`.

## Task 6: Verificar security group y flujo de red
- **Objetivo:** Confirmar que la red existente permite API Gateway -> Nginx sin abrir puertos innecesarios.
- **Archivos esperados:**
  - Revisar `modules/security_groups/sg_bastion/main.tf`
  - No modificar archivos si la regla `80` ya existe.
- **Tests requeridos:**
  - Validar que `sg_bastion` tenga ingreso TCP `80`.
  - Ejecutar `terraform plan` y revisar que no se creen cambios no relacionados en RDS, microservicios o VPC.
- **Criterio de finalización:**
  - `ec2-api-gw` puede recibir HTTP por `80`.
  - No se abren puertos adicionales.
  - RDS permanece privado.

## Task 7: Documentar uso del módulo
- **Objetivo:** Dejar instrucciones mínimas para futuros agentes o integrantes del equipo.
- **Archivos esperados:**
  - Modificar `modules/api_gateway/README.md`
- **Contenido requerido:**
  - Qué crea el módulo.
  - Variables requeridas.
  - Outputs.
  - Ejemplo de uso desde el root module.
  - Nota de seguridad indicando que esta versión usa integración pública sin VPC Link.
- **Tests requeridos:**
  - Revisión manual del README.
- **Criterio de finalización:**
  - El README explica cómo consumir el módulo sin leer su implementación completa.

## Task 8: Validación final en AWS Academy
- **Objetivo:** Validar que la infraestructura se puede planificar y aplicar en el entorno AWS Academy.
- **Archivos esperados:**
  - No crear archivos nuevos.
- **Comandos requeridos:**
  - `terraform fmt -recursive`
  - `terraform validate`
  - `terraform plan`
  - `terraform apply` solo si el plan fue revisado y aprobado.
- **Pruebas post-deploy:**
  - Consultar `terraform output api_gateway_base_url`.
  - Ejecutar una llamada HTTPS contra una ruta existente de Nginx.
  - Probar una ruta anidada para confirmar que `ANY /{proxy+}` funciona.
- **Criterio de finalización:**
  - API Gateway responde por HTTPS.
  - Nginx recibe las solicitudes.
  - Los microservicios siguen respondiendo detrás de Nginx.
  - No hay cambios fuera del alcance definido en la spec.

