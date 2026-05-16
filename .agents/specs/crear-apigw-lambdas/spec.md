# Spec: Crear API Gateway y Lambdas de Microservicios

## Objetivo
Reemplazar el Backend For Frontend actual por API Gateway, manteniendo para el frontend la misma superficie publica de rutas que hoy expone el BFF.

El despliegue debe crear Lambdas para los microservicios existentes en `~/Escritorio/fullstack3/` y configurar API Gateway para enrutar las llamadas del frontend directamente hacia la Lambda correspondiente.

## Contexto
El frontend actualmente depende de la URL del BFF y de sus rutas publicas. El BFF funciona principalmente como proxy HTTP: recibe requests bajo `/api/*`, reenvia a un microservicio y devuelve la respuesta.

Por lo tanto, API Gateway debe asumir el rol de fachada publica, evitando crear una Lambda BFF adicional.

Microservicios relevantes:

- `ms_authentication`
- `ms_asistencia_conducta`
- `BackGestion`
- `MsMensajeria`

## Alcance
- Crear o ajustar modulos Terraform para desplegar las Lambdas de los cuatro microservicios.
- No desplegar `backend_for_frontend` como Lambda.
- Crear un API Gateway HTTP publico como punto de entrada unico para el frontend.
- Configurar rutas en API Gateway equivalentes a las rutas publicas actuales del BFF.
- Integrar cada ruta de API Gateway con la Lambda del microservicio correcto.
- Configurar variables de entorno necesarias para cada Lambda.
- Conectar las Lambdas a la VPC/subredes privadas existentes cuando necesiten acceder a RDS.
- Usar la base de datos RDS privada existente en vez de `localhost`.
- Exponer outputs Terraform utiles: URL del API Gateway, nombres de Lambdas y ARNs/invoke ARNs relevantes.

## Fuera de Alcance
- Crear una Lambda para el BFF.
- Cambiar el frontend salvo que sea estrictamente necesario para apuntar a la nueva URL base del API Gateway.
- Reescribir la logica de negocio de los microservicios.
- Cambiar contratos de respuesta existentes de los microservicios.
- Crear una nueva base de datos.
- Agregar dependencias nuevas sin aprobacion previa.
- Guardar secretos reales en Terraform, specs, variables versionadas o codigo fuente.

## Rutas Publicas Esperadas
API Gateway debe conservar las rutas que consume el frontend a traves del BFF.

### Auth
Estas rutas deben apuntar a `ms_authentication`.

| Ruta publica API Gateway | Ruta interna esperada por el microservicio |
|---|---|
| `POST /api/auth/login` | `POST /api/auth/login` |
| `GET /api/auth/validate` | `GET /api/auth/validate` |
| `GET /api/auth/profile` | `GET /api/auth/profile` |

### Docente
Estas rutas deben conservar el namespace publico `/api/docente`, aunque internamente apunten a rutas de `ms_authentication` o `ms_asistencia_conducta`.

| Ruta publica API Gateway | Microservicio destino | Ruta interna esperada |
|---|---|---|
| `GET /api/docente/dashboard` | `ms_authentication` | `GET /api/teachers/me/dashboard` |
| `GET /api/docente/cursos` | `ms_asistencia_conducta` | `GET /api/docentes/cursos` |
| `GET /api/docente/cursos/{id}/alumnos` | `ms_asistencia_conducta` | `GET /api/cursos/{id}/alumnos` |
| `POST /api/docente/asistencia` | `ms_asistencia_conducta` | `POST /api/asistencia` |
| `GET /api/docente/asistencia/estudiante/{estudiante_id}` | `ms_asistencia_conducta` | `GET /api/asistencia/estudiante/{estudiante_id}` |
| `GET /api/docente/anotaciones` | `ms_asistencia_conducta` | `GET /api/anotaciones` |
| `POST /api/docente/anotaciones` | `ms_asistencia_conducta` | `POST /api/anotaciones` |

### Gestion Academica
Estas rutas deben apuntar a `BackGestion`. El frontend conserva el prefijo publico `/api/gestion`, aunque `BackGestion` exponga algunas rutas bajo otros prefijos.

| Ruta publica API Gateway | Ruta interna esperada por `BackGestion` |
|---|---|
| `GET /api/gestion/cursos` | `GET /api/academico/cursos` |
| `POST /api/gestion/cursos` | `POST /api/academico/cursos` |
| `DELETE /api/gestion/cursos/{id}` | `DELETE /api/academico/cursos/{id}` |
| `GET /api/gestion/asignaturas` | `GET /api/academico/asignaturas` |
| `POST /api/gestion/asignaturas` | `POST /api/academico/asignaturas` |
| `DELETE /api/gestion/asignaturas/{id}` | `DELETE /api/academico/asignaturas/{id}` |
| `POST /api/gestion/cad` | `POST /api/academico/cad` |
| `DELETE /api/gestion/cad/{id}` | `DELETE /api/academico/cad/{id}` |
| `GET /api/gestion/estudiantes` | `GET /api/estudiantes` |
| `GET /api/gestion/estudiantes/{id}` | `GET /api/estudiantes/{id}` |
| `GET /api/gestion/estudiantes/curso/{cursoId}` | `GET /api/estudiantes/curso/{cursoId}` |
| `POST /api/gestion/estudiantes` | `POST /api/estudiantes` |
| `PUT /api/gestion/estudiantes/{id}` | `PUT /api/estudiantes/{id}` |
| `DELETE /api/gestion/estudiantes/{id}` | `DELETE /api/estudiantes/{id}` |
| `GET /api/gestion/evaluaciones/cad/{cadId}` | `GET /api/evaluaciones/cad/{cadId}` |
| `POST /api/gestion/evaluaciones` | `POST /api/evaluaciones` |
| `PUT /api/gestion/evaluaciones/{id}` | `PUT /api/evaluaciones/{id}` |
| `DELETE /api/gestion/evaluaciones/{id}` | `DELETE /api/evaluaciones/{id}` |
| `GET /api/gestion/notas` | `GET /api/notas` |
| `GET /api/gestion/notas/estudiante/{id}` | `GET /api/notas/estudiante/{id}` |
| `GET /api/gestion/notas/curso/{cursoId}/asignatura/{asignaturaId}` | `GET /api/notas/curso/{cursoId}/asignatura/{asignaturaId}` |
| `POST /api/gestion/notas` | `POST /api/notas` |
| `POST /api/gestion/notas/bulk` | `POST /api/notas/bulk` |
| `GET /api/gestion/usuarios` | `GET /api/usuarios` |
| `POST /api/gestion/usuarios` | `POST /api/usuarios` |
| `PUT /api/gestion/usuarios/{id}` | `PUT /api/usuarios/{id}` |
| `DELETE /api/gestion/usuarios/{id}` | `DELETE /api/usuarios/{id}` |
| `GET /api/gestion/docentes/cad/all` | `GET /api/docentes/cad/all` |
| `GET /api/gestion/docentes` | `GET /api/docentes` |
| `POST /api/gestion/docentes` | `POST /api/docentes` |

### Mensajeria
Estas rutas deben apuntar a `MsMensajeria`.

| Ruta publica API Gateway | Ruta interna esperada por el microservicio |
|---|---|
| `POST /api/mensajes` | `POST /api/mensajes` |
| `GET /api/mensajes/recibidos/{email}` | `GET /api/mensajes/recibidos/{email}` |
| `GET /api/mensajes/enviados/{email}` | `GET /api/mensajes/enviados/{email}` |
| `PATCH /api/mensajes/leido/{id}` | `PATCH /api/mensajes/leido/{id}` |
| `GET /api/mensajes/descargar/{id}` | `GET /api/mensajes/descargar/{id}` |

## Reglas de Arquitectura
- API Gateway reemplaza al BFF como fachada publica.
- Cada microservicio debe seguir siendo propietario de su logica de negocio.
- El path publico del frontend debe mantenerse estable aunque el path interno del microservicio sea distinto.
- Si API Gateway HTTP no permite reescritura de paths con la granularidad requerida, el design debe proponer explicitamente una de estas alternativas:
  - ajustar los microservicios para aceptar tambien los paths publicos del BFF;
  - usar API Gateway REST con request mapping donde aplique;
  - introducir una capa minima de adaptacion solo para rutas incompatibles, justificando el trade-off.
- Las Lambdas que accedan a RDS deben estar en subredes privadas y usar el security group backend existente.
- La base de datos debe referenciarse con el endpoint real de RDS, no con `localhost`.
- Los secretos deben inyectarse mediante variables sensibles de Terraform, AWS Secrets Manager, SSM Parameter Store o mecanismo equivalente aprobado.
- No deben quedar API keys, passwords reales ni JWT secrets reales escritos en archivos versionados.

## Variables de Entorno Esperadas

### `ms_authentication`
- `PORT=3000`
- `DB_USER`
- `DB_PASSWORD`
- `DB_HOST`
- `DB_PORT=5432`
- `DB_DATABASE`
- `JWT_SECRET`

### `ms_asistencia_conducta`
- `PORT=3001`
- `DB_USER`
- `DB_PASSWORD`
- `DB_HOST`
- `DB_PORT=5432`
- `DB_DATABASE`
- `JWT_SECRET`

### `BackGestion`
Debe confirmarse el set exacto de variables que necesita en AWS. Si actualmente depende de `application.properties`, el design debe definir como se inyectaran:
- host de RDS;
- puerto;
- nombre de base de datos;
- usuario;
- password.

### `MsMensajeria`
- `PORT=3002`
- `DB_USER`
- `DB_PASSWORD`
- `DB_HOST`
- `DB_PORT=5432`
- `DB_DATABASE`
- `UPLOAD_PATH`
- `API_RESEND`

`UPLOAD_PATH` no debe usar rutas Windows locales en AWS. El design debe definir si se usara `/tmp`, EFS, S3 u otro almacenamiento compatible con Lambda.

## Seguridad
- API Gateway debe tener CORS compatible con el frontend.
- Las rutas que hoy requieren `Authorization: Bearer ...` deben seguir recibiendo y propagando ese header hasta el microservicio.
- No se exige implementar un authorizer en esta spec, salvo que se defina en el design como mejora explicita.
- Las Lambdas no deben quedar expuestas por Function URL publica.
- Los microservicios solo deben ser invocados a traves de API Gateway o permisos IAM definidos por Terraform.
- El spec actual no debe contener secretos reales. Cualquier secreto detectado debe rotarse fuera de esta tarea.

## Criterios de Aceptacion
- Terraform crea cuatro Lambdas de microservicios y no crea Lambda para `backend_for_frontend`.
- API Gateway expone una URL publica unica para el frontend.
- Las rutas publicas listadas en este spec existen en API Gateway.
- Cada ruta invoca el microservicio correcto.
- Las rutas con path publico distinto al path interno tienen una solucion documentada y probada.
- El frontend puede cambiar solo su URL base hacia API Gateway y conservar los paths actuales.
- Las Lambdas pueden conectarse a RDS privado usando `DB_HOST` real de RDS.
- No hay secretos reales nuevos en el repositorio.
- `terraform fmt -recursive` y `terraform validate` pasan.
- El plan de Terraform no destruye recursos existentes fuera del alcance esperado.

## Preguntas Abiertas
- Confirmar si se usara API Gateway HTTP o REST. HTTP API es mas simple, pero puede limitar reescritura de paths.
- Confirmar si se aceptara modificar microservicios para soportar paths publicos del BFF cuando API Gateway no pueda reescribirlos limpiamente.
- Confirmar estrategia de almacenamiento para adjuntos de `MsMensajeria`: `/tmp`, EFS o S3.
- Confirmar si los secretos se gestionaran con variables sensibles de Terraform, SSM Parameter Store o Secrets Manager.
- Confirmar si `BackGestion` ya esta preparado para leer configuracion de base de datos desde variables de entorno en Lambda.
