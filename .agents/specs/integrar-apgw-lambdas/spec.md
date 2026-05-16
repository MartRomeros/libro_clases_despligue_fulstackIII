# Spec: Integrar API Gateway HTTP con Lambdas de Microservicios

## Objetivo
Exponer los cuatro microservicios desplegados como AWS Lambda mediante un API Gateway HTTP publico, usando las mismas rutas que ya expone cada microservicio.

La API Gateway debe actuar como router hacia Lambdas, no como BFF ni como capa de transformacion de paths.

## Contexto
El proyecto despliega infraestructura en AWS Academy con Terraform. Existen cuatro microservicios principales:

- `ms_authentication`
- `ms_asistencia_conducta`
- `BackGestion`
- `MsMensajeria`

El BFF local ya no debe ser usado como referencia para corregir o traducir rutas. Los endpoints consumidos deben coincidir con los endpoints reales de cada microservicio.

## Alcance
- Usar API Gateway HTTP (`apigatewayv2`) como punto publico unico.
- Integrar API Gateway HTTP con las cuatro Lambdas existentes.
- Mantener Lambdas en subredes privadas con acceso a RDS cuando corresponda.
- Exponer rutas directas hacia cada microservicio sin `overwrite:path`.
- Configurar CORS para el frontend.
- Propagar headers, query params, path params y body mediante integracion Lambda proxy.
- Exponer output con la URL base del HTTP API.
- Incluir un ejemplo claro de llamada al endpoint de autenticacion.

## Fuera de Alcance
- Crear o desplegar Lambda para el BFF.
- Corregir rutas del BFF.
- Reescribir paths en API Gateway.
- Implementar API Gateway REST.
- Usar VTL mapping templates.
- Crear authorizers JWT en esta iteracion.
- Cambiar logica de negocio de microservicios.
- Crear nueva base de datos.
- Instalar dependencias nuevas.
- Hardcodear secretos en Terraform o archivos versionados.

## Rutas Esperadas
API Gateway HTTP debe exponer los endpoints propios de cada microservicio.

### Auth: `ms_authentication`
- `POST /api/auth/login`
- `GET /api/auth/validate`
- `GET /api/auth/profile`
- `GET /api/teachers/me/dashboard`

### Asistencia y Conducta: `ms_asistencia_conducta`
- `GET /api/docentes/cursos`
- `GET /api/cursos/{id}/alumnos`
- `POST /api/asistencia`
- `GET /api/asistencia/estudiante/{estudiante_id}`
- `GET /api/anotaciones`
- `POST /api/anotaciones`

### Gestion Academica: `BackGestion`
- `GET /api/academico/cursos`
- `POST /api/academico/cursos`
- `DELETE /api/academico/cursos/{id}`
- `GET /api/academico/asignaturas`
- `POST /api/academico/asignaturas`
- `DELETE /api/academico/asignaturas/{id}`
- `POST /api/academico/cad`
- `DELETE /api/academico/cad/{id}`
- `GET /api/estudiantes`
- `GET /api/estudiantes/{id}`
- `GET /api/estudiantes/curso/{cursoId}`
- `POST /api/estudiantes`
- `PUT /api/estudiantes/{id}`
- `DELETE /api/estudiantes/{id}`
- `GET /api/evaluaciones/cad/{cadId}`
- `POST /api/evaluaciones`
- `PUT /api/evaluaciones/{id}`
- `DELETE /api/evaluaciones/{id}`
- `GET /api/notas`
- `GET /api/notas/estudiante/{id}`
- `GET /api/notas/curso/{cursoId}/asignatura/{asignaturaId}`
- `POST /api/notas`
- `POST /api/notas/bulk`
- `GET /api/usuarios`
- `POST /api/usuarios`
- `PUT /api/usuarios/{id}`
- `DELETE /api/usuarios/{id}`
- `GET /api/docentes/cad/all`
- `GET /api/docentes`
- `POST /api/docentes`

### Mensajeria: `MsMensajeria`
- `POST /api/mensajes`
- `GET /api/mensajes/recibidos/{email}`
- `GET /api/mensajes/enviados/{email}`
- `PATCH /api/mensajes/leido/{id}`
- `GET /api/mensajes/descargar/{id}`

La subida de archivos de mensajeria queda fuera de alcance por ahora.

## Reglas de Arquitectura
- API Gateway HTTP debe usar integracion `AWS_PROXY` con `payload_format_version = "2.0"`.
- No debe usarse `request_parameters = { "overwrite:path" = ... }`.
- Cada ruta debe invocar la Lambda propietaria del endpoint.
- La autenticacion sigue dentro de los microservicios; API Gateway solo debe reenviar el header `Authorization`.
- No deben existir Lambda Function URLs publicas.
- Los permisos `aws_lambda_permission` deben permitir invocacion desde el HTTP API.
- Las Lambdas deben seguir usando el security group backend y subredes privadas.
- RDS debe seguir privado.

## Ejemplo de Uso
Si el output de Terraform entrega:

```text
api_gateway_invoke_url = https://abc123.execute-api.us-east-1.amazonaws.com/prod
```

El login se invoca asi:

```bash
curl -X POST "https://abc123.execute-api.us-east-1.amazonaws.com/prod/api/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@colegio.cl","password":"password"}'
```

## Criterios de Aceptacion
- Terraform crea o mantiene un API Gateway HTTP, no REST API.
- El root module usa `modules/api_gateway_http`.
- No se usa `modules/api_gateway_rest` desde `main.tf`.
- El modulo HTTP no usa `overwrite:path`.
- Las rutas listadas en este spec existen en el HTTP API.
- Cada ruta apunta a la Lambda correcta.
- `api_gateway_invoke_url` expone la URL base del HTTP API.
- `terraform fmt -recursive` pasa.
- `terraform validate` pasa en un entorno con providers inicializados.
- `terraform plan` no crea una Lambda BFF ni expone Function URLs.

## Riesgos
- Si el frontend aun llama rutas antiguas del BFF como `/api/gestion/cursos`, debera cambiar a las rutas reales del microservicio, por ejemplo `/api/academico/cursos`.
- HTTP API tiene menos capacidad de transformacion que REST API. Esta spec asume que no se requiere transformacion.
- En AWS Academy puede haber restricciones de IAM; por eso el modulo debe mantenerse simple y facil de depurar.
