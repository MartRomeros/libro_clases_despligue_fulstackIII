# Proyecto DevOps - Sistema de Gestión Escolar "Colegio O'Higgins"

Este repositorio contiene la infraestructura como código (IaC) y los scripts de automatización para el despliegue del sistema de gestión escolar del Colegio O'Higgins. El proyecto utiliza una arquitectura de microservicios desplegada en **AWS**, utilizando **Terraform** para el aprovisionamiento y **Docker** para la contenedorización.

## 🏗️ Arquitectura de Infraestructura

La infraestructura se despliega en una VPC personalizada y consta de los siguientes componentes:

*   **VPC**: Configurada con subredes públicas y privadas en múltiples zonas de disponibilidad.
*   **RDS (PostgreSQL 15)**: Base de datos relacional ubicada en subredes privadas para mayor seguridad.
*   **AWS Lambda**: Microservicio de autenticación (`ms-auth`) ejecutándose en contenedores.
*   **ECR**: Repositorio de imágenes Docker para los microservicios.
*   **S3**: Hosting de sitio estático para el frontend (configurado mediante script para evitar restricciones de AWS Academy).
*   **Bastion Host**: Instancia EC2 en subred pública para acceso seguro a la base de datos privada.
*   **Security Groups**: Reglas de firewall granulares para permitir el tráfico solo entre componentes necesarios.

---

## 🚀 Guía de Despliegue

Siga estos pasos en el orden indicado para un despliegue exitoso.

### 1. Configuración de Variables
Cree un archivo `terraform.tfvars` basado en el siguiente ejemplo:

```hcl
db_name     = "nombre_db"
username    = "usuario_admin"
password    = "tu_password_segura"
jwt_secret  = "tu_secreto_para_jwt"
```

### 2. Preparación del S3 (Frontend)
Debido a restricciones de AWS Academy con Terraform y Object Lock, el bucket de S3 se crea mediante un script:

```bash
chmod +x create_s3.sh
./create_s3.sh
```

### 3. Creación del Repositorio ECR
Primero, cree solo el repositorio ECR para poder subir la imagen:

```bash
terraform init
terraform apply -target=module.ecr_auth
```

### 4. Construcción y Subida de Imagen Docker
Utilice el script `push_image.sh` para construir la imagen del microservicio y subirla al ECR. Este script también fuerza la actualización de la Lambda.

> **Nota**: Asegúrese de que el código del microservicio se encuentra en la ruta `../ms_authentication` relativa a este directorio.

```bash
chmod +x push_image.sh
./push_image.sh
```

### 5. Despliegue de Infraestructura Completa
Una vez que la imagen está en ECR, despliegue el resto de los recursos:

```bash
terraform apply -auto-approve
```

---

## 🗄️ Inicialización de la Base de Datos

Para cargar el esquema inicial y los datos de prueba (`script.sql`), utilice el Bastion Host como puente:

1.  **Obtener la IP del Bastion y el Endpoint de RDS**:
    ```bash
    terraform output bastion_public_ip
    terraform output -raw db_host # (desde la configuración de RDS)
    ```
2.  **Conectarse al Bastion**:
    ```bash
    ssh -i vockey ec2-user@$(terraform output -raw bastion_public_ip)
    ```
3.  **Ejecutar el script SQL**:
    Desde su máquina local, puede enviar el script al RDS a través del Bastion:
    ```bash
    psql -h <DB_ENDPOINT> -U <USUARIO> -d <DB_NAME> -f script.sql
    ```

---

## 📊 Estructura de la Base de Datos

El archivo `script.sql` inicializa las siguientes entidades principales:
*   **Usuarios y Roles**: Administradores, Docentes, Estudiantes y Apoderados.
*   **Académico**: Cursos, Asignaturas, Evaluaciones y Notas.
*   **Seguimiento**: Asistencia y Anotaciones.

---

## 🛠️ Scripts Útiles

*   `create_s3.sh`: Configura el bucket S3 con hosting estático y políticas públicas.
*   `push_image.sh`: Automatiza el login en ECR, build de Docker, tag, push y update de Lambda.

## 📌 Requisitos
*   Terraform >= 1.0
*   AWS CLI configurado
*   Docker Desktop / Engine
*   Cliente de PostgreSQL (`psql`)
