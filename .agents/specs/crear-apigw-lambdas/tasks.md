# Tasks: Crear API Gateway REST y Lambdas de Microservicios

## Task 1: Ajustar variables y secretos Terraform
Objetivo:
Definir la interfaz de configuracion necesaria para Lambdas, API Gateway REST y secretos por `terraform.tfvars`.

Archivos esperados:
- `variables.tf`
- `terraform.tfvars` o `terraform.tfvars.example`, segun politica del repo

Cambios esperados:
- Marcar `db_password` como `sensitive = true`.
- Agregar `jwt_secret` como variable sensitive.
- Agregar `resend_api_key` como variable sensitive.
- Agregar `lambda_memory_size` con default razonable.
- Agregar `lambda_timeout` con default razonable.
- Agregar `api_stage_name` con default `prod`.
- Documentar que `terraform.tfvars` no debe versionarse si contiene secretos reales.

Tests requeridos:
- `terraform fmt -recursive`
- `terraform validate`

Criterio de finalizacion:
- Las variables existen, tienen tipos/descripciones claras y no hay secretos hardcodeados en archivos versionados.

## Task 2: Crear modulo Lambda reutilizable
Objetivo:
Crear un modulo generico para desplegar Lambdas desde imagenes ECR, evitando duplicar cuatro modulos casi iguales.

Archivos esperados:
- `modules/lambdas/microservice_lambda/main.tf`
- `modules/lambdas/microservice_lambda/variables.tf`
- `modules/lambdas/microservice_lambda/outputs.tf`

Cambios esperados:
- Crear `aws_lambda_function` con `package_type = "Image"`.
- Recibir `function_name`, `image_uri`, `private_subnets`, `security_group_id`, `environment_variables`, `memory_size` y `timeout`.
- Usar `LabRole` existente como role, siguiendo el patron actual.
- Configurar `vpc_config`.
- Exponer `function_name`, `arn` e `invoke_arn`.

Tests requeridos:
- `terraform fmt -recursive`
- `terraform validate`

Criterio de finalizacion:
- El modulo puede instanciar una Lambda de microservicio sin depender de nombres hardcodeados del BFF.

## Task 3: Instanciar Lambdas de los cuatro microservicios
Objetivo:
Crear las Lambdas para `ms_authentication`, `ms_asistencia_conducta`, `BackGestion` y `MsMensajeria`.

Archivos esperados:
- `main.tf`
- `outputs.tf`

Cambios esperados:
- Eliminar o dejar sin uso el modulo que crea la Lambda `backend_for_frontend`.
- Instanciar el modulo `microservice_lambda` cuatro veces.
- Usar imagenes ECR:
  - `ecr_colegio_auth`
  - `ecr_colegio_attendance`
  - `ecr_colegio_gestion`
  - `ecr_colegio_comunicaciones`
- Configurar variables de entorno:
  - Auth y asistencia con `DB_HOST`, `DB_PORT`, `DB_DATABASE`, `DB_USER`, `DB_PASSWORD`, `JWT_SECRET`.
  - BackGestion con `DB_URL`, `DB_USERNAME`, `DB_PASSWORD`.
  - Mensajeria con `DB_HOST`, `DB_PORT`, `DB_DATABASE`, `DB_USER`, `DB_PASSWORD`, `API_RESEND`, `UPLOAD_PATH = "/tmp"`.
- Usar `aws_db_instance.colegio_db.address`, no `localhost`.
- Exponer outputs de nombres y ARNs de Lambdas.

Tests requeridos:
- `terraform fmt -recursive`
- `terraform validate`
- `terraform plan`

Criterio de finalizacion:
- El plan muestra cuatro Lambdas de microservicios y no muestra creacion de Lambda BFF.

## Task 4: Crear modulo API Gateway REST base
Objetivo:
Crear el API Gateway REST publico con stage, CORS y permisos de invocacion a Lambdas.

Archivos esperados:
- `modules/api_gateway_rest/main.tf`
- `modules/api_gateway_rest/variables.tf`
- `modules/api_gateway_rest/outputs.tf`

Cambios esperados:
- Crear `aws_api_gateway_rest_api`.
- Crear deployment y stage usando `api_stage_name`.
- Configurar CORS para metodos requeridos.
- Preparar variables para recibir Lambdas destino e informacion de rutas.
- Crear `aws_lambda_permission` limitado al execution ARN del API Gateway.
- Exponer `invoke_url`.

Tests requeridos:
- `terraform fmt -recursive`
- `terraform validate`

Criterio de finalizacion:
- El modulo crea un REST API reutilizable y puede recibir integraciones Lambda.

## Task 5: Implementar rutas sin rewrite
Objetivo:
Configurar rutas que conservan el mismo path publico e interno.

Archivos esperados:
- `modules/api_gateway_rest/main.tf`
- opcional: archivos auxiliares dentro de `modules/api_gateway_rest/`

Rutas esperadas:
- `POST /api/auth/login`
- `GET /api/auth/validate`
- `GET /api/auth/profile`
- `POST /api/mensajes`
- `GET /api/mensajes/recibidos/{email}`
- `GET /api/mensajes/enviados/{email}`
- `PATCH /api/mensajes/leido/{id}`
- `GET /api/mensajes/descargar/{id}`

Cambios esperados:
- Crear resources y methods REST API.
- Integrar `/api/auth/*` con Lambda `ms_authentication`.
- Integrar `/api/mensajes/*` con Lambda `MsMensajeria`.
- Propagar headers, query params, path params y body.
- Propagar `Authorization`.

Tests requeridos:
- `terraform fmt -recursive`
- `terraform validate`
- Revision de `terraform plan` para confirmar rutas e integraciones.

Criterio de finalizacion:
- Las rutas sin rewrite quedan representadas en Terraform e integradas con la Lambda correcta.

## Task 6: Implementar rutas `/api/docente` con rewrite
Objetivo:
Configurar las rutas publicas de docente que antes resolvia el BFF y enviarlas al path interno correcto.

Archivos esperados:
- `modules/api_gateway_rest/main.tf`
- opcional: templates VTL en `modules/api_gateway_rest/templates/`

Rutas esperadas:
- `GET /api/docente/dashboard` -> `ms_authentication`, `/api/teachers/me/dashboard`
- `GET /api/docente/cursos` -> `ms_asistencia_conducta`, `/api/docentes/cursos`
- `GET /api/docente/cursos/{id}/alumnos` -> `ms_asistencia_conducta`, `/api/cursos/{id}/alumnos`
- `POST /api/docente/asistencia` -> `ms_asistencia_conducta`, `/api/asistencia`
- `GET /api/docente/asistencia/estudiante/{estudiante_id}` -> `ms_asistencia_conducta`, `/api/asistencia/estudiante/{estudiante_id}`
- `GET /api/docente/anotaciones` -> `ms_asistencia_conducta`, `/api/anotaciones`
- `POST /api/docente/anotaciones` -> `ms_asistencia_conducta`, `/api/anotaciones`

Cambios esperados:
- Crear mappings REST API no-proxy o templates equivalentes.
- Reescribir `path` en el evento Lambda.
- Mantener metodo HTTP original.
- Propagar body, query params, path params y headers.

Tests requeridos:
- `terraform fmt -recursive`
- `terraform validate`
- Revision de plan para confirmar integraciones correctas.

Criterio de finalizacion:
- Cada ruta `/api/docente` invoca la Lambda correcta y envia el path interno esperado.

## Task 7: Implementar rutas `/api/gestion` con rewrite
Objetivo:
Configurar las rutas publicas de gestion academica que antes exponia el BFF y enviarlas a `BackGestion`.

Archivos esperados:
- `modules/api_gateway_rest/main.tf`
- opcional: templates VTL en `modules/api_gateway_rest/templates/`

Rutas esperadas:
- Cursos, asignaturas y CAD hacia `/api/academico/*`.
- Estudiantes hacia `/api/estudiantes*`.
- Evaluaciones hacia `/api/evaluaciones*`.
- Notas hacia `/api/notas*`.
- Usuarios hacia `/api/usuarios*`.
- Docentes hacia `/api/docentes*`.

Cambios esperados:
- Crear resources y methods para las rutas listadas en `spec.md`.
- Reescribir paths publicos `/api/gestion/*` al path interno de `BackGestion`.
- Propagar body, query params, path params y headers.

Tests requeridos:
- `terraform fmt -recursive`
- `terraform validate`
- Revision de plan para confirmar rutas e integraciones.

Criterio de finalizacion:
- Todas las rutas `/api/gestion` del spec existen en Terraform y apuntan a `BackGestion` con path reescrito.

## Task 8: Integrar modulo API Gateway REST en root module
Objetivo:
Conectar el API Gateway REST con las Lambdas creadas desde `main.tf`.

Archivos esperados:
- `main.tf`
- `outputs.tf`

Cambios esperados:
- Instanciar `modules/api_gateway_rest`.
- Pasar `function_name` e `invoke_arn` de cada Lambda.
- Usar `api_stage_name`.
- Exponer output `api_gateway_invoke_url`.
- Remover outputs antiguos del BFF si ya no aplican.

Tests requeridos:
- `terraform fmt -recursive`
- `terraform validate`
- `terraform plan`

Criterio de finalizacion:
- El root module conecta API Gateway REST con las cuatro Lambdas y expone una URL publica unica.

## Task 9: Revisar seguridad, CORS y permisos
Objetivo:
Verificar que API Gateway y Lambdas queden expuestos solo del modo esperado.

Archivos esperados:
- `modules/api_gateway_rest/main.tf`
- `modules/lambdas/microservice_lambda/main.tf`
- `main.tf`

Cambios esperados:
- Confirmar que no existen Lambda Function URLs.
- Confirmar permisos `aws_lambda_permission` por API Gateway.
- Confirmar que las Lambdas usan subredes privadas.
- Confirmar que las Lambdas usan `sg_backend`.
- Confirmar que RDS permite acceso desde `sg_backend`.
- Confirmar CORS para frontend.

Tests requeridos:
- `terraform validate`
- Revision manual del plan.

Criterio de finalizacion:
- La superficie publica es API Gateway REST y no hay exposicion publica directa de Lambdas.

## Task 10: Validacion final de infraestructura
Objetivo:
Ejecutar validaciones finales antes de aplicar cambios.

Archivos esperados:
- Sin archivos nuevos obligatorios.

Comandos requeridos:
- `terraform fmt -recursive`
- `terraform validate`
- `terraform plan`

Criterio de finalizacion:
- `fmt` no deja cambios pendientes.
- `validate` pasa.
- `plan` no destruye VPC, RDS ni ECR inesperadamente.
- `plan` confirma:
  - cuatro Lambdas de microservicios;
  - cero Lambda BFF;
  - API Gateway REST;
  - rutas principales del spec;
  - outputs requeridos.

## Task 11: Pruebas manuales post-deploy
Objetivo:
Validar que el frontend pueda usar API Gateway como reemplazo del BFF.

Archivos esperados:
- Opcional: `docs/api-gateway-pruebas.md`

Pruebas requeridas:
- `POST /api/auth/login`
- `GET /api/auth/profile` con Bearer token.
- `GET /api/docente/dashboard` con Bearer token.
- `GET /api/docente/cursos` con Bearer token.
- `GET /api/gestion/cursos`
- `GET /api/gestion/usuarios`
- `GET /api/gestion/docentes/cad/all`
- `GET /api/mensajes/recibidos/{email}`

Criterio de finalizacion:
- Las rutas responden desde la URL del API Gateway.
- Las rutas con rewrite llegan al microservicio correcto.
- El frontend solo requiere cambiar la URL base.
- Se documentan fallos pendientes, si existen.
