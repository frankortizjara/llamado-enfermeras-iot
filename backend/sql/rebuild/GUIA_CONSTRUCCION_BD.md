# GUIA DE CONSTRUCCION DE BASE DE DATOS

## Sistema de Llamado de Enfermeras

---

## RESUMEN

Esta guia te lleva paso a paso para construir la base de datos `sistema_enfermeras` desde cero usando **DBeaver**.

**Archivos necesarios:**

| Archivo | Ubicacion | Proposito |
|---------|-----------|-----------|
| `01_setup_completo.sql` | `backend/sql/rebuild/` | Crea tablas, triggers, funciones e indices |
| `02_restaurar_secuencias.sql` | `backend/sql/rebuild/` | Corrige auto-increment despues de importar CSV |
| 9 archivos CSV corregidos | `backend/sql/csv_corregidos/` | Datos para poblar las tablas |

**Tiempo estimado:** 15-20 minutos

---

## ANTES DE EMPEZAR

### Requisitos previos

- PostgreSQL instalado y funcionando
- DBeaver instalado
- Acceso al usuario `postgres` (o un usuario con permisos de creacion de BD)

### Que problemas resuelve esta guia

Los CSV originales (en `backend/sql/csv/`) tenian estos problemas:

| CSV original | Problema | CSV corregido |
|-------------|----------|---------------|
| `hospitales_202601231018.csv` | Columna `id` no coincide con `hospital_id` de la tabla. Columna extra `TIPO _RA1` | `hospitales.csv` |
| `esp32_dispositivos_202601231018.csv` | Columnas `serial`/`mac` no coinciden con `numero_serial`/`direccion_mac` | `esp32_dispositivos.csv` |
| `variables_202601231018.csv` | Columnas extras `fecha_asignacion`/`fecha_registro` que la tabla no tiene | `variables.csv` |

Los demas CSV no tenian problemas y se copiaron con nombres simplificados a `csv_corregidos/`.

---

## PASO 1: CREAR LA BASE DE DATOS

### 1.1 Abrir DBeaver y conectarte a PostgreSQL

1. Abre DBeaver
2. En el panel izquierdo, haz clic derecho en tu conexion PostgreSQL
3. Click en **"Conectar"** (si no esta conectado)

### 1.2 Crear la base de datos

1. Haz clic derecho sobre **"Databases"** (o "Bases de datos")
2. Selecciona **"Create New Database"** (Crear nueva base de datos)
3. Escribe el nombre: `sistema_enfermeras`
4. Owner: `postgres`
5. Encoding: `UTF8`
6. Click **"OK"**

**ALTERNATIVA por SQL:** Si prefieres hacerlo por SQL, abre un nuevo SQL Editor sobre la conexion postgres y ejecuta:

```sql
CREATE DATABASE sistema_enfermeras;
```

### 1.3 Conectarte a la nueva base de datos

1. En el panel izquierdo, busca `sistema_enfermeras` dentro de Databases
2. Haz doble clic para expandirla y conectarte
3. Verifica que en la barra superior diga `sistema_enfermeras`

---

## PASO 2: EJECUTAR EL SCRIPT DE ESTRUCTURA

Este script crea las 13 tablas, triggers, indices y todas las funciones (stored procedures).

### 2.1 Abrir el script SQL

1. Estando conectado a `sistema_enfermeras`, haz clic derecho sobre la base de datos
2. Selecciona **"SQL Editor" > "Open SQL Script"** (o "Abrir script SQL")
3. Navega hasta: `backend/sql/rebuild/01_setup_completo.sql`
4. Click **"Abrir"**

### 2.2 Ejecutar el script

1. **IMPORTANTE:** Verifica en la barra superior que dice `sistema_enfermeras` como base de datos activa
2. Presiona **Ctrl+A** para seleccionar todo
3. Presiona **Ctrl+Enter** (o click en el boton "Execute SQL Script" / triangulo naranja)
4. Espera a que termine. Deberias ver mensajes de verificacion al final:

```
SETUP COMPLETADO EXITOSAMENTE
  Tablas creadas:     13
  Funciones creadas:  (varias)
  Triggers creados:   8
  Indices creados:    (varios)
```

### 2.3 Verificar las tablas creadas

1. En el panel izquierdo, expande `sistema_enfermeras` > `Schemas` > `public` > `Tables`
2. Deberias ver las siguientes 13 tablas:

```
alertas
areas
asignaciones_usuarios
camas
camas_essi
esp32_dispositivos
habitaciones
historial_alertas
historial_notas
historial_ocupacion
hospitales
usuarios
variables
```

Si las ves, el Paso 2 fue exitoso. Si no aparecen, haz clic derecho en "Tables" y selecciona "Refresh".

---

## PASO 3: IMPORTAR DATOS DESDE CSV

### IMPORTANTE: Orden de importacion

Las tablas tienen relaciones entre si (foreign keys), por lo que DEBES importar en este orden exacto. Si importas en otro orden, DBeaver te dara errores de "foreign key violation".

```
ORDEN OBLIGATORIO:
  1. hospitales          (no depende de nadie)
  2. usuarios            (no depende de nadie)
  3. esp32_dispositivos  (no depende de nadie)
  4. variables           (no depende de nadie)
  5. areas               (depende de hospitales)
  6. habitaciones        (depende de areas)
  7. camas               (depende de habitaciones)
  8. asignaciones_usuarios (depende de usuarios + areas)
  9. camas_essi          (OPCIONAL - se regenera desde API ESSI)
```

### 3.1 Como importar un CSV en DBeaver (procedimiento general)

Repite estos pasos para CADA tabla en el orden indicado arriba:

1. En el panel izquierdo, navega a: `sistema_enfermeras` > `Schemas` > `public` > `Tables`
2. Haz **clic derecho** sobre la tabla destino (ej: `hospitales`)
3. Selecciona **"Import Data"** (Importar datos)
4. Se abre el asistente de importacion:

#### Pantalla 1: Seleccionar origen
- Selecciona **"CSV"**
- Click **"Next"** (Siguiente)

#### Pantalla 2: Seleccionar archivo
- Click en **"Browse"** (o el icono de carpeta)
- Navega hasta: `backend/sql/csv_corregidos/`
- Selecciona el archivo CSV correspondiente a la tabla
- Click **"Next"**

#### Pantalla 3: Configuracion CSV
- **Delimiter (Delimitador):** `,` (coma) -- ya viene por defecto
- **Quote char (Caracter de comilla):** `"` (comilla doble) -- ya viene por defecto
- **Encoding:** `UTF-8`
- **Header:** Asegurate de que **"First line is header"** este MARCADO
- Click **"Next"**

#### Pantalla 4: Mapeo de columnas
- DBeaver muestra las columnas del CSV a la izquierda y las de la tabla a la derecha
- **Si los nombres coinciden**, DBeaver las mapea automaticamente (flecha verde)
- **Si alguna columna no mapea**, puedes arrastrarla manualmente
- Verifica que TODAS las columnas del CSV tengan una flecha hacia una columna de la tabla
- Click **"Next"**

#### Pantalla 5: Configuracion de carga
- **Transfer method:** Normalmente "INSERT" esta bien
- Click **"Proceed"** (Proceder)

#### Resultado
- DBeaver muestra el progreso de importacion
- Al terminar, debe decir algo como "Transfer finished: X rows transferred"
- Si hay errores, lee el mensaje. Los errores comunes son:
  - **"duplicate key"**: La tabla ya tiene datos. Solucion: vaciar la tabla primero (ver seccion "Si hay errores")
  - **"foreign key violation"**: Importaste en el orden incorrecto. Solucion: importa primero la tabla padre

---

### 3.2 Importar tabla por tabla

Sigue el procedimiento de la seccion 3.1 para cada tabla. Aqui el detalle especifico:

#### 1. hospitales

| Configuracion | Valor |
|--------------|-------|
| Tabla destino | `hospitales` |
| Archivo CSV | `csv_corregidos/hospitales.csv` |
| Registros esperados | 169 |
| Notas | Columnas ya corregidas (`hospital_id` en vez de `id`) |

#### 2. usuarios

| Configuracion | Valor |
|--------------|-------|
| Tabla destino | `usuarios` |
| Archivo CSV | `csv_corregidos/usuarios.csv` |
| Registros esperados | 2 |
| Notas | Contrasenas ya vienen hasheadas (bcrypt). Admin password: `CAMBIA_ESTA_PASSWORD` |

#### 3. esp32_dispositivos

| Configuracion | Valor |
|--------------|-------|
| Tabla destino | `esp32_dispositivos` |
| Archivo CSV | `csv_corregidos/esp32_dispositivos.csv` |
| Registros esperados | 43 |
| Notas | Columnas ya corregidas (`numero_serial`, `direccion_mac`) |

#### 4. variables

| Configuracion | Valor |
|--------------|-------|
| Tabla destino | `variables` |
| Archivo CSV | `csv_corregidos/variables.csv` |
| Registros esperados | 2 |
| Notas | CSV corregido: solo `id` y `nombre_variable` |

#### 5. areas (DEPENDE DE hospitales)

| Configuracion | Valor |
|--------------|-------|
| Tabla destino | `areas` |
| Archivo CSV | `csv_corregidos/areas.csv` |
| Registros esperados | 2 |
| Notas | Las areas referencian `cod_ses=5` que debe existir en hospitales |

#### 6. habitaciones (DEPENDE DE areas)

| Configuracion | Valor |
|--------------|-------|
| Tabla destino | `habitaciones` |
| Archivo CSV | `csv_corregidos/habitaciones.csv` |
| Registros esperados | 5 |
| Notas | Habitaciones 101-105 del area 1 (CIR1) |

#### 7. camas (DEPENDE DE habitaciones)

| Configuracion | Valor |
|--------------|-------|
| Tabla destino | `camas` |
| Archivo CSV | `csv_corregidos/camas.csv` |
| Registros esperados | 1 |
| Notas | Solo 1 cama registrada |

#### 8. asignaciones_usuarios (DEPENDE DE usuarios + areas)

| Configuracion | Valor |
|--------------|-------|
| Tabla destino | `asignaciones_usuarios` |
| Archivo CSV | `csv_corregidos/asignaciones_usuarios.csv` |
| Registros esperados | 2 |
| Notas | Asigna admin al area CIR1 y test al area TEST |

#### 9. camas_essi (OPCIONAL)

| Configuracion | Valor |
|--------------|-------|
| Tabla destino | `camas_essi` |
| Archivo CSV | `csv_corregidos/camas_essi.csv` |
| Registros esperados | ~4421 |
| Notas | OPCIONAL. Estos datos se regeneran automaticamente cuando el backend sincroniza con la API ESSI. Si no importas este CSV, la tabla empezara vacia y se llenara con la primera sincronizacion. |

---

## PASO 4: RESTAURAR SECUENCIAS

Despues de importar TODOS los CSV, debes ejecutar este script para corregir los contadores auto-increment.

**Por que es necesario?** Cuando importas CSV con IDs especificos (ej: id=35, id=43), PostgreSQL no actualiza automaticamente su contador interno. Sin este paso, el siguiente registro nuevo podria intentar usar un ID que ya existe y fallar.

### 4.1 Ejecutar el script

1. Haz clic derecho sobre `sistema_enfermeras`
2. Selecciona **"SQL Editor" > "Open SQL Script"**
3. Navega hasta: `backend/sql/rebuild/02_restaurar_secuencias.sql`
4. Presiona **Ctrl+A** y luego **Ctrl+Enter**
5. Deberias ver un resumen con el conteo de registros por tabla

---

## PASO 5: VERIFICACION FINAL

### 5.1 Verificar conteos

Abre un SQL Editor y ejecuta:

```sql
SELECT 'hospitales' AS tabla, COUNT(*) AS registros FROM hospitales
UNION ALL SELECT 'usuarios', COUNT(*) FROM usuarios
UNION ALL SELECT 'areas', COUNT(*) FROM areas
UNION ALL SELECT 'habitaciones', COUNT(*) FROM habitaciones
UNION ALL SELECT 'camas', COUNT(*) FROM camas
UNION ALL SELECT 'esp32_dispositivos', COUNT(*) FROM esp32_dispositivos
UNION ALL SELECT 'variables', COUNT(*) FROM variables
UNION ALL SELECT 'asignaciones_usuarios', COUNT(*) FROM asignaciones_usuarios
UNION ALL SELECT 'camas_essi', COUNT(*) FROM camas_essi;
```

**Resultados esperados:**

| Tabla | Registros |
|-------|-----------|
| hospitales | 169 |
| usuarios | 2 |
| areas | 2 |
| habitaciones | 5 |
| camas | 1 |
| esp32_dispositivos | 43 |
| variables | 2 |
| asignaciones_usuarios | 2 |
| camas_essi | 0 o ~4421 (si importaste el CSV) |

### 5.2 Verificar login del admin

```sql
SELECT * FROM sp_obtener_usuario('admin');
```

Debe retornar un JSON con `"estado": "success"` y los datos del admin.

### 5.3 Verificar funciones

```sql
SELECT proname, pronargs
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'public' AND proname LIKE 'sp_%'
ORDER BY proname;
```

Debe mostrar al menos 18 funciones.

---

## CONFIGURACION DEL BACKEND

Verifica que el archivo `backend/.env` tenga los datos correctos:

```env
PGUSER=postgres
PGHOST=localhost
PGDATABASE=sistema_enfermeras
PGPASSWORD=admin
PGPORT=5432
```

Ajusta `PGPASSWORD` con tu contrasena real de PostgreSQL.

---

## CREDENCIALES DE ACCESO AL SISTEMA

| Usuario | Contrasena | Rol | Area asignada |
|---------|-----------|-----|---------------|
| admin | CAMBIA_ESTA_PASSWORD | admin | CIR1 |
| test | (desconocida) | test | TEST |

---

## SOLUCION DE PROBLEMAS

### Error: "duplicate key value violates unique constraint"

**Causa:** La tabla ya tiene datos (quizas de un intento anterior).

**Solucion:** Antes de importar, vaciar la tabla. En DBeaver:
1. Clic derecho sobre la tabla > "View Data" (para confirmar que tiene datos)
2. Abrir SQL Editor y ejecutar:
```sql
-- CUIDADO: Esto borra TODOS los datos de la tabla
TRUNCATE TABLE nombre_tabla CASCADE;
```
Nota: `CASCADE` borra tambien datos de tablas que dependen de esta.

**Si necesitas vaciar TODO y empezar de cero:**
```sql
-- Ejecutar en este orden (inverso a las dependencias)
TRUNCATE TABLE historial_ocupacion, historial_alertas, historial_notas CASCADE;
TRUNCATE TABLE alertas CASCADE;
TRUNCATE TABLE asignaciones_usuarios CASCADE;
TRUNCATE TABLE camas CASCADE;
TRUNCATE TABLE camas_essi CASCADE;
TRUNCATE TABLE habitaciones CASCADE;
TRUNCATE TABLE areas CASCADE;
TRUNCATE TABLE esp32_dispositivos CASCADE;
TRUNCATE TABLE variables CASCADE;
TRUNCATE TABLE usuarios CASCADE;
TRUNCATE TABLE hospitales CASCADE;
```

### Error: "violates foreign key constraint"

**Causa:** Importaste una tabla antes de importar la tabla padre.

**Solucion:** Respeta el orden de importacion de la seccion 3.2. Ejemplo:
- `areas` necesita que `hospitales` ya tenga datos (porque `areas.cod_ses` referencia `hospitales.cod_ses`)
- `habitaciones` necesita que `areas` ya tenga datos

### Error: columnas no se mapean automaticamente

**Causa:** El nombre de columna en el CSV no coincide con el de la tabla.

**Solucion:** Usa los CSV de la carpeta `csv_corregidos/`, NO los de `csv/`. Los corregidos ya tienen los nombres de columna correctos.

### Las columnas de camas_essi aparecen en minusculas en DBeaver

Esto es normal. PostgreSQL almacena los nombres con comillas como son (`"codHabCama"`), pero DBeaver a veces los muestra en minusculas. La importacion deberia funcionar correctamente si usas los CSV de `csv_corregidos/`.

### Error: "value too long for type character varying(12)" en esp32_dispositivos

**Causa:** Algun numero_serial en el CSV es mas largo que 12 caracteres.

**Solucion:** Si esto ocurre, puedes ampliar el campo antes de importar:
```sql
ALTER TABLE esp32_dispositivos ALTER COLUMN numero_serial TYPE VARCHAR(50);
ALTER TABLE esp32_dispositivos ALTER COLUMN direccion_mac TYPE VARCHAR(50);
```

---

## RESUMEN DE PASOS

```
PASO 1: Crear base de datos "sistema_enfermeras" en DBeaver
PASO 2: Ejecutar 01_setup_completo.sql (tablas + funciones)
PASO 3: Importar CSV en orden:
        1. hospitales.csv
        2. usuarios.csv
        3. esp32_dispositivos.csv
        4. variables.csv
        5. areas.csv
        6. habitaciones.csv
        7. camas.csv
        8. asignaciones_usuarios.csv
        9. camas_essi.csv (OPCIONAL)
PASO 4: Ejecutar 02_restaurar_secuencias.sql
PASO 5: Verificar conteos y login
```
