# Guia de Despliegue SQL - Sistema Llamado de Enfermeras

Esta guia describe el orden correcto para ejecutar los archivos SQL en una nueva instalacion.

---

## Requisitos Previos

- PostgreSQL 12 o superior
- Usuario con permisos de creacion de tablas, funciones e indices
- Base de datos creada (ej: `llamado_enfermeras`)

---

## Orden de Ejecucion

### FASE 1: Setup Inicial (Obligatorio)

| # | Archivo | Descripcion |
|---|---------|-------------|
| 1 | `00_complete_setup.sql` | Crea todas las tablas base, stored procedures y estructura inicial |
| 2 | `02_indexes.sql` | Crea indices para optimizar consultas |
| 3 | `03_seed_data.sql` | Datos semilla basicos (areas, hospitales) |

```bash
# Ejecutar en orden:
psql -U usuario -d llamado_enfermeras -f 00_complete_setup.sql
psql -U usuario -d llamado_enfermeras -f 02_indexes.sql
psql -U usuario -d llamado_enfermeras -f 03_seed_data.sql
```

### FASE 2: Datos de Prueba (Opcional - Solo desarrollo)

| # | Archivo | Descripcion |
|---|---------|-------------|
| 4 | `04_test_data.sql` | Datos de prueba para desarrollo |
| 5 | `05_test_data_essi.sql` | Datos de prueba del sistema EsSi |

```bash
# Solo en ambiente de desarrollo:
psql -U usuario -d llamado_enfermeras -f 04_test_data.sql
psql -U usuario -d llamado_enfermeras -f 05_test_data_essi.sql
```

### FASE 3: Correcciones y Mejoras (Obligatorio)

Estas migraciones corrigen bugs y mejoran las funciones existentes.

| # | Archivo | Descripcion |
|---|---------|-------------|
| 6 | `06_fix_function_essi_v2.sql` | Corrige funcion de consulta EsSi |
| 7 | `07_fix_alertas_function.sql` | Corrige funcion de alertas |
| 8 | `10_fix_stored_procedures.sql` | Correccion general de SPs |
| 9 | `11_fix_sp_habitaciones_essi.sql` | Mejora consulta de habitaciones |
| 10 | `12_fix_response_format.sql` | Estandariza formato de respuestas |
| 11 | `13_fix_data_consistency.sql` | Corrige consistencia de datos |
| 12 | `14_fix_sp_agregar_registro.sql` | Corrige SP de registro de alertas |
| 13 | `15_fix_sp_cargar_data_essi.sql` | Corrige carga de datos EsSi |

```bash
psql -U usuario -d llamado_enfermeras -f 06_fix_function_essi_v2.sql
psql -U usuario -d llamado_enfermeras -f 07_fix_alertas_function.sql
psql -U usuario -d llamado_enfermeras -f 10_fix_stored_procedures.sql
psql -U usuario -d llamado_enfermeras -f 11_fix_sp_habitaciones_essi.sql
psql -U usuario -d llamado_enfermeras -f 12_fix_response_format.sql
psql -U usuario -d llamado_enfermeras -f 13_fix_data_consistency.sql
psql -U usuario -d llamado_enfermeras -f 14_fix_sp_agregar_registro.sql
psql -U usuario -d llamado_enfermeras -f 15_fix_sp_cargar_data_essi.sql
```

### FASE 4: Sincronizacion EsSi (Obligatorio)

| # | Archivo | Descripcion |
|---|---------|-------------|
| 14 | `16_add_sync_date.sql` | Agrega campo de fecha de sincronizacion |
| 15 | `17_fix_all_sync_sps.sql` | Corrige todos los SPs de sincronizacion |
| 16 | `18_fix_sync_sequence_and_upsert.sql` | Corrige secuencia y agrega UPSERT |
| 17 | `19_alter_nota_varchar8.sql` | Amplia campo nota a 8 caracteres |

```bash
psql -U usuario -d llamado_enfermeras -f 16_add_sync_date.sql
psql -U usuario -d llamado_enfermeras -f 17_fix_all_sync_sps.sql
psql -U usuario -d llamado_enfermeras -f 18_fix_sync_sequence_and_upsert.sql
psql -U usuario -d llamado_enfermeras -f 19_alter_nota_varchar8.sql
```

### FASE 5: Historial y Auditoria (Obligatorio)

| # | Archivo | Descripcion |
|---|---------|-------------|
| 18 | `20_historial_tables_and_sp_updates.sql` | Crea tablas de historial (notas, alertas, ocupacion) |

```bash
psql -U usuario -d llamado_enfermeras -f 20_historial_tables_and_sp_updates.sql
```

### FASE 6: Analytics y Roles (Obligatorio)

| # | Archivo | Descripcion |
|---|---------|-------------|
| 19 | `21_add_rol_to_login_sp.sql` | Agrega rol al SP de login |
| 20 | `22_sp_reconocer_alerta.sql` | SP para reconocer alertas (jefe de area) |
| 21 | `23_analytics_stored_procedures.sql` | 4 SPs de analytics para dashboard |

```bash
psql -U usuario -d llamado_enfermeras -f 21_add_rol_to_login_sp.sql
psql -U usuario -d llamado_enfermeras -f 22_sp_reconocer_alerta.sql
psql -U usuario -d llamado_enfermeras -f 23_analytics_stored_procedures.sql
```

### FASE 7: Verificación y Corrección (Recomendado)

| # | Archivo | Descripcion |
|---|---------|-------------|
| 22 | `25_verify_and_fix_sp.sql` | Verifica y corrige SPs para que registren en historial |
| 23 | `26_fix_analytics_date_comparison.sql` | **IMPORTANTE**: Corrige comparación de fechas en analytics |

```bash
psql -U usuario -d llamado_enfermeras -f 25_verify_and_fix_sp.sql
psql -U usuario -d llamado_enfermeras -f 26_fix_analytics_date_comparison.sql
```

---

## Archivos NO requeridos

Estos archivos son versiones antiguas o scripts especiales que NO deben ejecutarse:

| Archivo | Razon |
|---------|-------|
| `06_fix_function_essi.sql` | Reemplazado por `06_fix_function_essi_v2.sql` |
| `08_reset_and_load_csv.sql` | Script de reset, solo para desarrollo |
| `09_load_csv_data.sql` | Carga desde CSV, solo si tienes los archivos |
| `postgress.sql` | Archivo legacy, no usar |
| `trigger.sql` | Triggers opcionales, revisar antes de usar |

---

## Verificacion Post-Instalacion

Ejecuta estas consultas para verificar que todo se instalo correctamente:

```sql
-- Verificar tablas principales
SELECT table_name FROM information_schema.tables
WHERE table_schema = 'public'
ORDER BY table_name;

-- Verificar stored procedures
SELECT proname FROM pg_proc
WHERE pronamespace = 'public'::regnamespace
AND proname LIKE 'sp_%'
ORDER BY proname;

-- Verificar tablas de historial
SELECT COUNT(*) as total FROM historial_notas;
SELECT COUNT(*) as total FROM historial_alertas;
SELECT COUNT(*) as total FROM historial_ocupacion;

-- Verificar que el login retorna rol
SELECT * FROM sp_obtener_usuario('admin');
```

---

## Script de Instalacion Rapida

Crea un archivo `install_all.sh` con el siguiente contenido:

```bash
#!/bin/bash
DB_USER="tu_usuario"
DB_NAME="llamado_enfermeras"
SQL_DIR="./sql"

echo "=== Instalando Sistema Llamado de Enfermeras ==="

# Fase 1: Setup inicial
echo "Fase 1: Setup inicial..."
psql -U $DB_USER -d $DB_NAME -f $SQL_DIR/00_complete_setup.sql
psql -U $DB_USER -d $DB_NAME -f $SQL_DIR/02_indexes.sql
psql -U $DB_USER -d $DB_NAME -f $SQL_DIR/03_seed_data.sql

# Fase 3: Correcciones
echo "Fase 3: Correcciones..."
psql -U $DB_USER -d $DB_NAME -f $SQL_DIR/06_fix_function_essi_v2.sql
psql -U $DB_USER -d $DB_NAME -f $SQL_DIR/07_fix_alertas_function.sql
psql -U $DB_USER -d $DB_NAME -f $SQL_DIR/10_fix_stored_procedures.sql
psql -U $DB_USER -d $DB_NAME -f $SQL_DIR/11_fix_sp_habitaciones_essi.sql
psql -U $DB_USER -d $DB_NAME -f $SQL_DIR/12_fix_response_format.sql
psql -U $DB_USER -d $DB_NAME -f $SQL_DIR/13_fix_data_consistency.sql
psql -U $DB_USER -d $DB_NAME -f $SQL_DIR/14_fix_sp_agregar_registro.sql
psql -U $DB_USER -d $DB_NAME -f $SQL_DIR/15_fix_sp_cargar_data_essi.sql

# Fase 4: Sincronizacion
echo "Fase 4: Sincronizacion..."
psql -U $DB_USER -d $DB_NAME -f $SQL_DIR/16_add_sync_date.sql
psql -U $DB_USER -d $DB_NAME -f $SQL_DIR/17_fix_all_sync_sps.sql
psql -U $DB_USER -d $DB_NAME -f $SQL_DIR/18_fix_sync_sequence_and_upsert.sql
psql -U $DB_USER -d $DB_NAME -f $SQL_DIR/19_alter_nota_varchar8.sql

# Fase 5: Historial
echo "Fase 5: Historial..."
psql -U $DB_USER -d $DB_NAME -f $SQL_DIR/20_historial_tables_and_sp_updates.sql

# Fase 6: Analytics
echo "Fase 6: Analytics..."
psql -U $DB_USER -d $DB_NAME -f $SQL_DIR/21_add_rol_to_login_sp.sql
psql -U $DB_USER -d $DB_NAME -f $SQL_DIR/22_sp_reconocer_alerta.sql
psql -U $DB_USER -d $DB_NAME -f $SQL_DIR/23_analytics_stored_procedures.sql

# Fase 7: Verificacion y correccion
echo "Fase 7: Verificacion..."
psql -U $DB_USER -d $DB_NAME -f $SQL_DIR/25_verify_and_fix_sp.sql
psql -U $DB_USER -d $DB_NAME -f $SQL_DIR/26_fix_analytics_date_comparison.sql

echo "=== Instalacion completada ==="
```

---

## Crear Usuario Jefe de Area

Para que un usuario pueda acceder al dashboard de analytics, debe tener el rol `jefe_area`:

```sql
-- 1. Registrar usuario (si no existe)
SELECT * FROM sp_registrar_usuario(
    0,                          -- id (0 = nuevo)
    'Dr. Juan Perez',           -- nombre
    'jperez',                   -- usuario
    '$2b$10$hash_bcrypt_aqui',  -- clave (hash bcrypt)
    true                        -- estado
);

-- 2. Asignar a area con rol jefe_area
SELECT * FROM sp_asignar_usuario(
    0,              -- id (0 = nueva asignacion)
    1,              -- usuario_id (del paso anterior)
    1,              -- area_id (ej: UCI = 1)
    'jefe_area',    -- rol
    true            -- estado
);
```

---

## Troubleshooting

### Error: "relation already exists"
Ejecuta el archivo nuevamente, los scripts usan `IF NOT EXISTS`.

### Error: "function does not exist"
Asegurate de ejecutar los archivos en el orden correcto.

### Error de permisos
Verifica que el usuario tenga permisos de CREATE en el schema public.

### Login no retorna rol
Ejecuta `21_add_rol_to_login_sp.sql` para actualizar el SP de login.

### Analytics muestra 0 a pesar de tener datos
Ejecuta `26_fix_analytics_date_comparison.sql`. Los SPs originales comparaban TIMESTAMP
completo, excluyendo registros del mismo día con hora diferente a 00:00:00.

---

## Contacto

Para soporte tecnico, contactar al equipo de desarrollo.
