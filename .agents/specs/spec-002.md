- edita el `script.sql`. debes insertar registros en cada tabla que exista en la base de datos.
- deben tener un maximo de 20 registros por tabla
- los datos deben ser coherentes entre si

## Realizado

Se ha actualizado el archivo `script.sql` con una carga de datos inicial coherente y completa para todas las tablas del sistema.

### Justificación de los cambios:

1.  **Cobertura Total**: Se insertaron registros en las 15 tablas definidas en el esquema (incluyendo tablas de especialización como `docentes`, `estudiantes` y `apoderados`, así como tablas relacionales y maestras como `salas`).
2.  **Volumen de Datos**: Se configuró un total de **20 usuarios** (2 administradores, 6 docentes, 8 estudiantes y 4 apoderados), cumpliendo estrictamente con el límite de máximo 20 registros por tabla.
3.  **Coherencia y Consistencia**:
    *   Los `usuario_id` en las tablas hijas (`docentes`, `estudiantes`, `apoderados`) coinciden con sus respectivos roles en la tabla `usuarios`.
    *   Las relaciones en `curso_asignatura_docente` vinculan correctamente a los docentes con sus especialidades y asignaturas existentes.
    *   Las notas y asistencias están asociadas a estudiantes y evaluaciones válidas.
    *   Se incluyeron datos en las tablas `salas` y `sala_evaluacione_asistencia` que anteriormente estaban vacías.
4.  **Limpieza de Datos**: Se actualizó la sentencia `TRUNCATE` para incluir las nuevas tablas, asegurando que el script sea re-ejecutable sin errores de duplicidad.