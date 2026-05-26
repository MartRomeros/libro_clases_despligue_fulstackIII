# Spec: Crear API Gateway para exponer Nginx por HTTPS

## Objetivo
Configurar un API Gateway administrado por AWS para exponer por HTTPS las rutas que hoy atiende Nginx en la instancia `ec2-api-gw`.

El flujo esperado es:

```text
frontend en S3 -> HTTPS -> AWS API Gateway -> HTTP -> Nginx en ec2-api-gw -> HTTP -> microservicios -> RDS
```

La finalidad principal es que el frontend pueda consumir los endpoints del backend usando HTTPS sin cambiar la responsabilidad actual de Nginx como proxy hacia los microservicios.

## Alcance
- Crear la infraestructura Terraform necesaria para un AWS API Gateway administrado.
- Usar una integración HTTP desde API Gateway hacia Nginx en `ec2-api-gw`.
- Exponer las rutas de Nginx mediante HTTPS usando el endpoint administrado de API Gateway.
- Configurar rutas proxy para que API Gateway reenvíe las solicitudes a Nginx sin duplicar la lógica de enrutamiento.
- Publicar como output la URL HTTPS base que deberá consumir el frontend.
- Verificar que el security group asociado a `ec2-api-gw` permita tráfico HTTP entrante por el puerto `80`.
- Mantener el flujo interno desde Nginx hacia los microservicios y desde los microservicios hacia RDS.

## Fuera de alcance
- Crear o reemplazar Nginx.
- Modificar la lógica de los microservicios.
- Modificar la base de datos RDS.
- Crear un ALB o NLB.
- Crear una integración privada con VPC Link, salvo que durante el diseño se decida cambiar a una arquitectura privada.
- Configurar dominio personalizado o certificado ACM para API Gateway.
- Implementar autenticación, autorización, WAF, throttling avanzado o validadores de request.
- Cambiar el frontend desplegado en S3.

## Decisiones técnicas
- Se usará AWS API Gateway administrado, no una EC2 actuando como gateway.
- La integración será HTTP pública hacia `ec2-api-gw`, usando su IP pública o DNS público.
- No se requiere VPC Link para esta primera implementación, porque el target Nginx ya está accesible por HTTP desde internet mediante el security group público.
- API Gateway será responsable de terminar HTTPS en el endpoint administrado por AWS.
- Nginx seguirá siendo responsable de enrutar hacia los microservicios internos.
- El puerto esperado de Nginx es `80`.

## Consideraciones sobre VPC Link
VPC Link no es necesario si API Gateway se integra contra un endpoint HTTP público, como la IP pública o DNS público de `ec2-api-gw`.

VPC Link sería necesario si se quisiera que API Gateway llegara a Nginx por una ruta privada dentro de la VPC. Esa alternativa normalmente requeriría agregar recursos adicionales, como un NLB o ALB privado, y ajustar security groups y subnets. Para el alcance actual en AWS Academy, se prefiere la integración HTTP pública por ser más simple y alineada con la infraestructura existente.

## Reglas de seguridad
- El frontend debe consumir el backend usando HTTPS a través de API Gateway.
- API Gateway puede comunicarse con Nginx usando HTTP por puerto `80`.
- El security group `sg_bastion`, usado por `ec2-api-gw`, ya permite entrada por `80` desde `var.public_ingress_cidr`.
- No se deben abrir puertos adicionales si no son necesarios.
- Los microservicios deben permanecer en subnets privadas.
- RDS debe permanecer sin acceso público.
- La conexión entre Nginx y los microservicios debe seguir restringida por security groups.

## Supuestos
- La instancia `ec2-api-gw` ejecuta Nginx y escucha por HTTP en el puerto `80`.
- Las rutas necesarias del backend ya están configuradas en Nginx.
- El frontend está o estará publicado en S3 y consumirá una URL HTTPS de API Gateway.
- El entorno AWS Academy permite crear recursos de API Gateway.
- La IP pública o DNS público de `ec2-api-gw` puede usarse como origen de la integración HTTP.

## Riesgos técnicos
- Si la IP pública de `ec2-api-gw` cambia, la integración de API Gateway podría quedar apuntando a un destino inválido. Se debe preferir el DNS público de la instancia si está disponible como output.
- Como Nginx queda accesible por HTTP público, existe una ruta directa que evita API Gateway. Para una arquitectura más segura se debería evaluar VPC Link con un balanceador privado o restringir el origen permitido cuando sea viable.
- Si Nginx no escucha en el puerto `80`, API Gateway responderá con errores `5xx`.
- Si las rutas proxy de API Gateway no preservan path y método, algunas rutas del backend podrían fallar.
- Si el frontend usa CORS, puede ser necesario configurar CORS en API Gateway, en Nginx o en los servicios según dónde se respondan los headers.

## Casos borde
- Requests con paths anidados, por ejemplo `/api/auth/login` o `/api/asistencia/estudiantes/1`.
- Métodos distintos de `GET`, como `POST`, `PUT`, `PATCH` y `DELETE`.
- Requests preflight `OPTIONS` si el frontend ejecuta llamadas CORS desde S3.
- Errores de Nginx o microservicios propagados a través de API Gateway.
- Timeouts cuando un microservicio demore más de lo permitido por API Gateway.

## Criterios de aceptación
- Dado el frontend desplegado en S3, cuando consume la URL base de API Gateway, entonces la comunicación ocurre por HTTPS.
- Dada una ruta existente en Nginx, cuando se invoca mediante API Gateway, entonces la solicitud llega a Nginx preservando path y método.
- Dado un endpoint de microservicio publicado por Nginx, cuando se consume desde API Gateway, entonces la respuesta del microservicio se devuelve al cliente.
- Dado el security group `sg_bastion`, cuando se revisan sus reglas, entonces existe ingreso TCP por puerto `80`.
- Dado el RDS, cuando se revisa la infraestructura, entonces continúa sin acceso público.
- Dado el código Terraform, cuando se ejecuta `terraform fmt` y `terraform validate`, entonces ambos comandos finalizan correctamente.
- Dado el output de Terraform, cuando termina el despliegue, entonces existe una URL HTTPS base de API Gateway para configurar en el frontend.

