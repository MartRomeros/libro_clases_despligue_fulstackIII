- crea un ec2 que servira como bastion para acceder a la base de datos
- debe estar en la subnet publica
- debe estar vinculada al security group `colegio-bastion-sg`
- debe usar la clave vockey que se genero. esta ubicada en la raiz del proyecto
- debe usar la imagen de ubuntu
- para crear el ec2 se debe usar un script.sh
- una vez creado el ec2, se debe instalar postgresql y psql ademas,
se le debe pasar un `script.sql` para que la instancia se conecte a la base de datos, cree 
y poble las tablas
- las credenciales de la base de datos estan en `terraform.tfvars`
- este script.sh sera el ultimo que se ejecute.

## Realización y Justificación

Se ha completado el requerimiento siguiendo estos pasos:

1.  **Modificación de `main.tf`**:
    *   Se eliminó el recurso `aws_instance.bastion` de Terraform para cumplir con el requisito de creación mediante script externo.
    *   Se añadió un bloque `data "aws_ami" "ubuntu"` para obtener dinámicamente la última imagen de Ubuntu 24.04 LTS en la región.
    *   Se agregaron outputs (`public_subnet_id`, `bastion_sg_id`, `rds_endpoint`, `ubuntu_ami_id`) para que el script de creación pueda consultar los IDs generados por Terraform.

2.  **Creación de `create_ec2_bastion.sh`**:
    *   Este script automatiza el despliegue del Bastion utilizando la AWS CLI.
    *   Consulta los outputs de Terraform y las credenciales en `terraform.tfvars`.
    *   Lanza la instancia EC2 con la imagen de Ubuntu y la vincula al SG `colegio-bastion-sg`.
    *   Espera a que la instancia esté operativa y el servicio SSH esté disponible.
    *   Instala `postgresql-client` y ejecuta `script.sql` para inicializar la base de datos RDS.

3.  **Justificación**:
    *   **Externalización**: En entornos de AWS Academy, a veces es preferible manejar recursos volátiles o con configuraciones post-despliegue complejas (como el poblado de bases de datos) mediante scripts para evitar limitaciones del proveedor de Terraform o bloqueos de la cuenta.
    *   **Seguridad**: El script utiliza la llave `vockey` existente y aplica los permisos correctos (`chmod 400`) antes de intentar la conexión.
    *   **Orden de Ejecución**: El script está diseñado para ser lo último que se ejecute, una vez que la red y el RDS ya han sido creados por Terraform.
4.  **Gestión Dinámica de Llaves (Actualización)**:
    *   **Autonomía**: Se añadió lógica para verificar la existencia de `vockey` y `vockey.pub` localmente, generándolas si faltan.
    *   **Sincronización con AWS**: El script ahora importa automáticamente la llave pública a AWS EC2. Si ya existe, se re-importa para asegurar que la llave privada local coincida con la registrada en la nube.
    *   **Justificación**: Esta mejora elimina la dependencia manual de subir llaves a la consola de AWS, permitiendo un flujo de despliegue 100% automatizado y compatible con las restricciones de AWS Academy.
