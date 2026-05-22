# Spec: Crear instancias EC2 para plataforma Colegio Bernardo O'Higgins

## Objetivo
Provisionar 6 instancias EC2 en AWS Academy usando Terraform para alojar los componentes publicos y privados de la plataforma de libro de clases digital del Colegio Bernardo O'Higgins.

Las instancias deben reutilizar la infraestructura existente del repositorio, especialmente los modulos de `modules/`, la VPC ya definida y la AMI Ubuntu declarada en el root module.

## Contexto
El proyecto despliega infraestructura IaC para una plataforma academica basada en microservicios. Ya existen recursos Terraform para:

- VPC y subredes en `modules/vpc`.
- Security groups en `modules/security_groups/sg_bastion`, `modules/security_groups/sg_backend` y `modules/security_groups/sg_database`.
- Modulo EC2 reutilizable en `modules/ec2`.
- Data source `data.aws_ami.ubuntu` en `main.tf` para Ubuntu 24.04.
- Base de datos PostgreSQL privada ya conectada al security group de base de datos.
- Un bucket S3 sin CloudFront servira el frontend estatico y consumira los servicios a traves de `ec2-api-gw`.

## Alcance
- Crear 6 instancias EC2 usando el modulo existente `modules/ec2`.
- Usar instancia tipo `t3.micro` para todas las EC2.
- Usar Ubuntu como sistema operativo mediante `data.aws_ami.ubuntu.id`.
- Usar el mismo par de claves existente para todas las EC2.
- Instalar `git` y `docker` mediante `user_data` o mecanismo equivalente dentro del modulo EC2.
- Asignar 2 instancias publicas al security group publico:
  - `ec2-bastion`
  - `ec2-api-gw`
- Asignar 4 instancias privadas al security group `sg_backend`:
  - `ec2-ms-auth`
  - `ec2-ms-asistencia`
  - `ec2-ms-gestion`
  - `ec2-ms-comunicaciones`
- Ubicar `ec2-bastion` y `ec2-api-gw` en subredes publicas.
- Ubicar las 4 instancias de microservicios en subredes privadas.
- Exponer outputs con las 6 direcciones/comandos necesarios para conectarse por SSH.
- Exponer la IP o DNS publico de `ec2-api-gw` para que el S3 consuma la API.
- Mejorar el modulo `modules/ec2` para que soporte correctamente Ubuntu, Docker, Git, volumen raiz configurable y outputs utiles.
- Mantener compatibilidad con AWS Academy y sus restricciones.

## Fuera de alcance
- Crear una VPC nueva.
- Crear o reemplazar el par de claves.
- Ejecutar `terraform apply` sin aprobacion explicita.
- Crear CloudFront, Load Balancers o dominios DNS.
- Crear el bucket S3, salvo que una spec posterior lo solicite. Esta spec solo debe dejar claro que el consumidor publico sera un S3 sin CloudFront.
- Desplegar contenedores de aplicacion.
- Cambiar la base de datos RDS salvo que sea estrictamente necesario para conectividad.
- Agregar dependencias nuevas sin preguntar primero.

## Reglas de infraestructura
- Se debe reutilizar `modules/ec2`; no duplicar recursos `aws_instance` en el root module salvo justificacion en `design.md`.
- El nombre del par de claves usado por Terraform debe corresponder al key pair existente en AWS. El archivo local disponible es `165387-vockey.pem`; no se debe versionar ni modificar la clave privada.
- Las conexiones SSH deben usar el usuario `ubuntu`, no `ec2-user`, porque la AMI objetivo es Ubuntu.
- El almacenamiento raiz debe ser suficiente para ejecutar Docker y contenedores pequenos. Valor esperado: al menos 20 GiB con volumen `gp3` o equivalente compatible.
- Las instancias deben etiquetarse con estos nombres exactos:
  - `ec2-bastion`
  - `ec2-api-gw`
  - `ec2-ms-auth`
  - `ec2-ms-asistencia`
  - `ec2-ms-gestion`
  - `ec2-ms-comunicaciones`
- Si se usan `count` o `for_each`, la salida debe seguir siendo estable y legible.
- `ec2-api-gw` sera el unico punto de entrada HTTP/HTTPS publico hacia los servicios backend.
- `ec2-bastion` se usara solo para administracion SSH de las demas EC2 y del RDS.

## Reglas de seguridad
- El security group publico debe permitir SSH entrante por puerto 22 desde una fuente definida. Para desarrollo en AWS Academy puede ser `0.0.0.0/0`, pero debe quedar documentado como riesgo y preferiblemente parametrizable.
- El security group publico debe permitir HTTP 80 y HTTPS 443 entrante hacia `ec2-api-gw` para que el frontend en S3 consuma la API.
- `sg_backend` debe permitir SSH 22 solo desde el security group publico, para que `ec2-bastion` pueda administrar las EC2 privadas.
- `sg_backend` debe permitir trafico TCP desde el security group publico hacia los puertos `3000`, `3001`, `3002` y `8080`, para que `ec2-api-gw` pueda consumir los microservicios.
- `sg_backend` no debe permitir trafico entrante directo desde Internet.
- Todas las instancias deben permitir salida a Internet para instalar paquetes y descargar imagenes Docker.
- No exponer RDS publicamente.
- El RDS debe seguir siendo accesible desde los security groups necesarios para administracion y consumo interno, sin hacerlo publico.
- No guardar secretos en texto plano dentro de la spec ni en archivos versionados.

## Outputs requeridos
Al finalizar `terraform apply`, Terraform debe mostrar informacion suficiente para conectarse por SSH:

- Para `ec2-bastion`: IP publica o DNS publico y comando sugerido `ssh -i 165387-vockey.pem ubuntu@<bastion_public_ip>`.
- Para `ec2-api-gw`: IP publica o DNS publico, URL base HTTP/HTTPS y comando sugerido de SSH.
- Para cada microservicio privado: IP privada y comando sugerido usando salto por bastion, por ejemplo `ssh -i 165387-vockey.pem -J ubuntu@<bastion_public_ip> ubuntu@<backend_private_ip>`.
- Un output tipo mapa con nombres de instancia y direcciones para facilitar operacion.

## Criterios de aceptacion
- Dado el codigo Terraform actualizado, cuando se ejecuta `terraform fmt -recursive`, entonces no quedan archivos sin formatear.
- Dado el codigo Terraform actualizado, cuando se ejecuta `terraform validate`, entonces la configuracion es valida.
- Dado un `terraform plan`, cuando se revisan los cambios, entonces se observan exactamente 6 instancias EC2 nuevas o gestionadas por el modulo EC2 existente.
- Dado el plan, entonces `ec2-bastion` y `ec2-api-gw` usan el security group publico.
- Dado el plan, entonces `ec2-ms-auth`, `ec2-ms-asistencia`, `ec2-ms-gestion` y `ec2-ms-comunicaciones` usan `module.sg_backend.sg_backend_id`.
- Dado el plan, entonces todas las instancias usan `t3.micro`, la AMI Ubuntu de `data.aws_ami.ubuntu.id` y el mismo key pair.
- Dado el `user_data`, cuando una instancia termina de inicializar, entonces `git --version` y `docker --version` funcionan.
- Dado el modulo EC2 actualizado, entonces permite configurar volumen raiz de al menos 20 GiB sin duplicar codigo por instancia.
- Dado el modelo de red, cuando el S3 consume servicios, entonces debe hacerlo contra `ec2-api-gw` por HTTP/HTTPS publico.
- Dado el modelo de red, cuando `ec2-api-gw` consume microservicios, entonces puede conectarse a `3000`, `3001`, `3002` y `8080` en `sg_backend`.
- Dado el modelo de red, cuando se intenta acceder por SSH a microservicios desde Internet, entonces no debe estar permitido.
- Dado el modelo de red, cuando se intenta acceder por SSH a microservicios desde `ec2-bastion`, entonces debe estar permitido.
- Dado `terraform output`, entonces se muestran las 6 rutas/direcciones de conexion SSH requeridas.

## Preguntas abiertas para resolver en design.md
- Cual es el nombre exacto del key pair en AWS: `165387-vockey`, `165387-vockey.pem` u otro valor visible en la consola de AWS Academy.
- Que puerto exacto escuchara cada microservicio:
  - `ec2-ms-auth`
  - `ec2-ms-asistencia`
  - `ec2-ms-gestion`
  - `ec2-ms-comunicaciones`
- Si `ec2-api-gw` solo enruta trafico HTTP en `80/443` o tambien ejecutara contenedores propios en `3000`, `3001`, `3002` o `8080`.
- Si el acceso SSH publico debe quedar abierto a `0.0.0.0/0` por limitacion academica o restringido a una IP/CIDR.

## Riesgos tecnicos
- Exponer SSH, HTTP o HTTPS a `0.0.0.0/0` simplifica AWS Academy, pero aumenta la superficie de ataque.
- Microservicios en subred privada mejoran seguridad, pero requieren bastion, NAT y outputs con jump host para operar.
- `ec2-api-gw` publico queda como punto unico de entrada; si falla, el S3 no podra consumir los servicios.
- El modulo EC2 actual debe ajustarse para Ubuntu: instala Docker pero agrega al usuario `ec2-user`; en Ubuntu corresponde `ubuntu`.
- Si el modulo no permite configurar volumen raiz, habra que extender su contrato con variables descriptivas y defaults seguros.
