# Design: Crear API Gateway para exponer Nginx por HTTPS

## Contexto
La infraestructura actual despliega una VPC, security groups, varias EC2 y una base de datos RDS PostgreSQL usando Terraform. La instancia `ec2-api-gw` está en una subnet pública, usa el security group `sg_bastion` y representa el punto donde debe vivir Nginx como proxy hacia los microservicios privados.

La spec requiere reemplazar el consumo directo del frontend hacia Nginx por un endpoint HTTPS administrado por AWS API Gateway.

## Arquitectura propuesta
Se agregará un módulo Terraform local `modules/api_gateway` encargado de crear un AWS API Gateway HTTP API. El root module invocará ese módulo pasando como origen HTTP el endpoint público de `ec2-api-gw`.

```text
Frontend S3
  -> HTTPS
AWS API Gateway HTTP API
  -> HTTP
Nginx en ec2-api-gw:80
  -> HTTP
Microservicios en subnets privadas
  -> PostgreSQL RDS privado
```

Se recomienda usar **API Gateway v2 HTTP API** en vez de REST API porque el caso de uso es un proxy HTTP simple hacia Nginx, con menor configuración y menor costo operativo.

## Componentes Terraform

### Nuevo módulo: `modules/api_gateway`
Responsabilidad: crear y exponer un API Gateway HTTP API con integración proxy hacia Nginx.

Archivos esperados:
- `modules/api_gateway/main.tf`
- `modules/api_gateway/variables.tf`
- `modules/api_gateway/outputs.tf`
- `modules/api_gateway/README.md`

Recursos esperados:
- `aws_apigatewayv2_api`
- `aws_apigatewayv2_integration`
- `aws_apigatewayv2_route`
- `aws_apigatewayv2_stage`

Rutas mínimas:
- `ANY /{proxy+}` para reenviar paths anidados.
- `ANY /` para cubrir llamadas a la raíz si Nginx expone healthcheck o landing route.

Integración:
- Tipo: `HTTP_PROXY`
- Método: `ANY`
- URI: `http://<public_dns_o_ip_de_ec2-api-gw>`
- Connection type: `INTERNET`

### Cambios en root module
Archivos probablemente modificados:
- `main.tf`
- `outputs.tf`

El root module deberá instanciar `module "api_gateway"` después de `module "ec2_instances"`, porque necesita la IP pública o DNS público de `ec2-api-gw`.

Se debe preferir `module.ec2_instances["ec2-api-gw"].public_dns` si está disponible. Si `public_dns` no funciona en AWS Academy, se puede usar `module.ec2_instances["ec2-api-gw"].public_ip`.

El output actual `api_gateway_base_url`, que hoy apunta a `http://<ip_ec2>`, deberá cambiar para entregar la URL HTTPS del API Gateway administrado.

## Flujo de datos
1. El frontend desplegado en S3 realiza requests HTTPS hacia el invoke URL de API Gateway.
2. API Gateway recibe la petición, preserva path y método, y la reenvía por HTTP hacia Nginx.
3. Nginx aplica las rutas ya configuradas y reenvía hacia el microservicio correspondiente.
4. El microservicio consulta RDS usando la red privada existente.
5. La respuesta vuelve por el mismo camino hasta el frontend.

## Seguridad
- API Gateway termina TLS usando su endpoint administrado por AWS.
- La comunicación API Gateway -> Nginx será HTTP pública hacia `ec2-api-gw:80`.
- `sg_bastion` ya permite ingreso TCP `80`, por lo que no se requieren nuevos puertos para este flujo.
- RDS debe mantenerse privado.
- Los microservicios deben mantenerse en subnets privadas.
- Esta implementación no evita que un cliente llame directamente a Nginx por HTTP si conoce la IP pública de `ec2-api-gw`. Ese riesgo queda aceptado para AWS Academy por simplicidad.

## VPC Link
No se usará VPC Link en esta implementación.

Motivo: VPC Link se justifica cuando API Gateway debe alcanzar un destino privado dentro de la VPC. En este proyecto, Nginx ya está en una EC2 pública con ingreso HTTP permitido. Usar VPC Link agregaría más piezas, típicamente un NLB o ALB, y aumentaría el alcance fuera de lo pedido.

Si más adelante se requiere bloquear el acceso directo a Nginx y obligar todo el tráfico a pasar por API Gateway, se deberá diseñar una segunda iteración con integración privada.

## CORS
La implementación debe evaluar si el frontend en S3 necesita CORS. Para una primera versión, se puede configurar CORS en API Gateway con orígenes parametrizables.

Valor recomendado para desarrollo académico:
- `allow_methods`: `["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"]`
- `allow_headers`: `["content-type", "authorization"]`
- `allow_origins`: variable `cors_allowed_origins`

Si el frontend todavía no tiene dominio definitivo, se puede usar `["*"]` temporalmente y documentar el riesgo.

## Variables propuestas del módulo
- `name`: nombre del API Gateway.
- `nginx_base_url`: URL HTTP base de Nginx, por ejemplo `http://ec2-x-x-x-x.compute-1.amazonaws.com`.
- `stage_name`: nombre del stage, recomendado `"$default"` para simplificar el invoke URL.
- `cors_allowed_origins`: lista de orígenes permitidos para CORS.
- `tags`: tags comunes.

## Outputs propuestos del módulo
- `api_id`
- `api_endpoint`
- `invoke_url`
- `stage_name`

## Cambios en base de datos
No aplica. RDS no cambia.

## Dependencias nuevas
No se deben instalar dependencias. Se usarán recursos nativos del provider `hashicorp/aws`, ya declarado con versión `~> 5.0`.

## Riesgos
- La IP pública de `ec2-api-gw` puede cambiar si la instancia se recrea. El DNS público también puede cambiar si se reemplaza la instancia, pero es más legible para la integración.
- AWS Academy puede restringir algunos servicios o permisos de API Gateway. Se debe validar con `terraform plan`.
- Si Nginx no está escuchando en `80`, API Gateway devolverá errores `5xx`.
- Si CORS no se configura donde corresponde, el navegador puede bloquear requests aunque el backend responda correctamente.
- El acceso directo por HTTP a Nginx seguirá abierto mientras `ec2-api-gw` sea público.

## Estrategia de testing
- Ejecutar `terraform fmt -recursive`.
- Ejecutar `terraform validate`.
- Ejecutar `terraform plan` para confirmar que se crean los recursos de API Gateway sin modificar RDS ni microservicios.
- Después de aplicar, probar `curl` contra la URL HTTPS de API Gateway usando una ruta existente de Nginx.
- Probar una ruta anidada para validar `ANY /{proxy+}`.
- Si el frontend ya existe, configurar su base URL con el output HTTPS y validar una llamada real desde navegador.

