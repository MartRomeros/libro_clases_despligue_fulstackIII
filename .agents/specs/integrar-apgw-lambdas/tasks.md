# Tasks: Integrar API Gateway HTTP con Lambdas

## Task 1: Revisar rutas reales de microservicios
Objetivo:
Confirmar que las rutas declaradas en `spec.md` coinciden con los routers/controladores actuales.

Archivos esperados:
- Sin cambios obligatorios.

Tests requeridos:
- Revision estatica con `rg` sobre routers/controladores.

Criterio de finalizacion:
- Existe una lista final de rutas por microservicio.
- No se usan rutas heredadas del BFF como fuente de verdad.

## Task 2: Simplificar `modules/api_gateway_http`
Objetivo:
Eliminar cualquier transformacion de path en el modulo HTTP API.

Archivos esperados:
- `modules/api_gateway_http/main.tf`

Cambios esperados:
- Eliminar `overwrite_path` de `route_definitions`.
- Eliminar `request_parameters = { "overwrite:path" = ... }`.
- Mantener `integration_type = "AWS_PROXY"`.
- Mantener `payload_format_version = "2.0"`.

Tests requeridos:
- `terraform fmt -recursive`
- Revision estatica para confirmar que no existe `overwrite:path`.

Criterio de finalizacion:
- API Gateway HTTP queda como router directo.

## Task 3: Definir rutas de `ms_authentication`
Objetivo:
Exponer endpoints reales del microservicio de autenticacion.

Archivos esperados:
- `modules/api_gateway_http/main.tf`

Rutas:
- `POST /api/auth/login`
- `GET /api/auth/validate`
- `GET /api/auth/profile`
- `GET /api/teachers/me/dashboard`

Tests requeridos:
- `terraform fmt -recursive`
- `terraform validate` en entorno con providers.

Criterio de finalizacion:
- Todas las rutas apuntan a la Lambda `auth`.

## Task 4: Definir rutas de `ms_asistencia_conducta`
Objetivo:
Exponer endpoints reales de asistencia y conducta.

Archivos esperados:
- `modules/api_gateway_http/main.tf`

Rutas:
- `GET /api/docentes/cursos`
- `GET /api/cursos/{id}/alumnos`
- `POST /api/asistencia`
- `GET /api/asistencia/estudiante/{estudiante_id}`
- `GET /api/anotaciones`
- `POST /api/anotaciones`

Tests requeridos:
- `terraform fmt -recursive`
- `terraform validate` en entorno con providers.

Criterio de finalizacion:
- Todas las rutas apuntan a la Lambda `attendance`.

## Task 5: Definir rutas de `BackGestion`
Objetivo:
Exponer endpoints reales de gestion academica.

Archivos esperados:
- `modules/api_gateway_http/main.tf`

Rutas:
- `/api/academico/*`
- `/api/estudiantes*`
- `/api/evaluaciones*`
- `/api/notas*`
- `/api/usuarios*`
- `/api/docentes*`

Tests requeridos:
- `terraform fmt -recursive`
- `terraform validate` en entorno con providers.

Criterio de finalizacion:
- Todas las rutas academicas apuntan a la Lambda `gestion`.
- No quedan rutas `/api/gestion/*`.

## Task 6: Definir rutas de `MsMensajeria`
Objetivo:
Exponer endpoints reales de mensajeria.

Archivos esperados:
- `modules/api_gateway_http/main.tf`

Rutas:
- `POST /api/mensajes`
- `GET /api/mensajes/recibidos/{email}`
- `GET /api/mensajes/enviados/{email}`
- `PATCH /api/mensajes/leido/{id}`
- `GET /api/mensajes/descargar/{id}`

Tests requeridos:
- `terraform fmt -recursive`
- `terraform validate` en entorno con providers.

Criterio de finalizacion:
- Todas las rutas apuntan a la Lambda `mensajes`.
- No se habilita subida de archivos como requisito.

## Task 7: Revisar root module y outputs
Objetivo:
Confirmar que el root module usa HTTP API y expone la URL correcta.

Archivos esperados:
- `main.tf`
- `outputs.tf`

Cambios esperados:
- Mantener `module "api_gateway_http"`.
- No usar `module "api_gateway_rest"`.
- Mantener `api_gateway_invoke_url`.

Tests requeridos:
- `terraform fmt -recursive`
- Revision estatica con `rg "api_gateway_rest|aws_api_gateway_rest_api"`.

Criterio de finalizacion:
- El root module queda conectado solo al HTTP API.

## Task 8: Validacion en AWS Academy
Objetivo:
Validar que la infraestructura puede planificarse en el entorno real.

Archivos esperados:
- Sin cambios obligatorios.

Comandos requeridos:
- `terraform init`
- `terraform validate`
- `terraform plan`

Criterio de finalizacion:
- El plan no crea API Gateway REST.
- El plan no crea Lambda BFF.
- El plan crea o actualiza un HTTP API.
- El plan conserva Lambdas de los cuatro microservicios.

## Task 9: Pruebas manuales post-deploy
Objetivo:
Verificar comportamiento real de API Gateway HTTP.

Pruebas requeridas:
- `POST /api/auth/login`
- `GET /api/auth/profile`
- `GET /api/docentes/cursos`
- `GET /api/academico/cursos`
- `GET /api/usuarios`
- `GET /api/mensajes/recibidos/{email}`

Criterio de finalizacion:
- Cada ruta responde desde la URL de API Gateway HTTP.
- El header `Authorization` llega a los microservicios protegidos.
- Las rutas publicadas coinciden con los endpoints reales, no con aliases del BFF.
