-- =====================================================
-- SCRIPT: Cargar datos desde CSV
-- =====================================================
-- Ejecutar desde psql con variable CSV_PATH:
--   psql -d sistema_enfermeras -v CSV_PATH="'/ruta/a/csv'" -f 09_load_csv_data.sql
--
-- O edita la variable csv_dir abajo con tu ruta
-- =====================================================

-- Define la ruta a los archivos CSV (EDITAR ESTA RUTA)
\set csv_dir '/home/claude-user/proyectos/ProyectoF/sistema_llamado_de_enfermeras/backend/sql/csv'

SET client_encoding = 'UTF8';

BEGIN;

-- =====================================================
-- 1. USUARIOS
-- =====================================================
\echo 'Cargando usuarios...'
\copy usuarios(id, nombre, usuario, clave, estado, fecha_registro, fecha_modificacion) FROM :'csv_dir'/usuarios_202601231018.csv WITH (FORMAT csv, HEADER true, QUOTE '"', ENCODING 'UTF8');

-- =====================================================
-- 2. VARIABLES
-- =====================================================
\echo 'Cargando variables...'
\copy variables(id, nombre_variable, fecha_asignacion, fecha_registro) FROM :'csv_dir'/variables_202601231018.csv WITH (FORMAT csv, HEADER true, QUOTE '"', ENCODING 'UTF8');

-- =====================================================
-- 3. AREAS
-- =====================================================
\echo 'Cargando areas...'
\copy areas(id, cod_ses, nombre, estado, fecha_registro, fecha_modificacion) FROM :'csv_dir'/areas_202601231018.csv WITH (FORMAT csv, HEADER true, QUOTE '"', ENCODING 'UTF8');

-- =====================================================
-- 4. HABITACIONES
-- =====================================================
\echo 'Cargando habitaciones...'
\copy habitaciones(id, area_id, nombre, estado, fecha_registro, fecha_modificacion) FROM :'csv_dir'/habitaciones_202601231018.csv WITH (FORMAT csv, HEADER true, QUOTE '"', ENCODING 'UTF8');

-- =====================================================
-- 5. CAMAS
-- =====================================================
\echo 'Cargando camas...'
\copy camas(id, habitacion_id, nombre, paciente, estado, fecha_registro, fecha_modificacion) FROM :'csv_dir'/camas_202601231018.csv WITH (FORMAT csv, HEADER true, QUOTE '"', ENCODING 'UTF8');

-- =====================================================
-- 6. CAMAS_ESSI (columnas con comillas)
-- =====================================================
\echo 'Cargando camas_essi...'
\copy camas_essi(id, "codHabCama", "codHab", "codCama", "apeNomPac", "desEstCama", "desSerCama", "diashospi", "fechaIngreso", "nroDocIdePac", "nroHisCliCas", "tipoDocIdePac", estado, fecha_registro, fecha_modificacion, nota, fecha_nota) FROM :'csv_dir'/camas_essi_202601231018.csv WITH (FORMAT csv, HEADER true, QUOTE '"', ENCODING 'UTF8');

-- =====================================================
-- 7. ESP32_DISPOSITIVOS (mapeo de columnas)
-- =====================================================
\echo 'Cargando esp32_dispositivos...'

-- Crear tabla temporal con estructura del CSV
CREATE TEMP TABLE temp_esp32 (
    id INTEGER,
    serial VARCHAR(12),
    mac VARCHAR(17),
    ip VARCHAR(45),
    estado BOOLEAN,
    fecha_registro TIMESTAMP,
    fecha_modificacion TIMESTAMP
);

\copy temp_esp32 FROM :'csv_dir'/esp32_dispositivos_202601231018.csv WITH (FORMAT csv, HEADER true, QUOTE '"', ENCODING 'UTF8');

-- Insertar con mapeo de columnas
INSERT INTO esp32_dispositivos (id, numero_serial, direccion_mac, ip, estado, fecha_registro, fecha_modificacion)
SELECT id,
       COALESCE(NULLIF(TRIM(serial), ''), 'UNKNOWN'),
       COALESCE(NULLIF(TRIM(mac), ''), '00:00:00:00:00:00'),
       NULLIF(TRIM(ip), ''),
       COALESCE(estado, true),
       fecha_registro,
       fecha_modificacion
FROM temp_esp32
WHERE serial IS NOT NULL AND serial != '';

DROP TABLE temp_esp32;

-- =====================================================
-- 8. HOSPITALES (mapeo de columnas)
-- =====================================================
\echo 'Cargando hospitales...'

-- Crear tabla temporal con estructura del CSV
CREATE TEMP TABLE temp_hospitales (
    id INTEGER,
    cod_renaes INTEGER,
    cod_ses INTEGER,
    cod_eess INTEGER,
    tipo_ra1 VARCHAR(10),
    tipo VARCHAR(50),
    nombre VARCHAR(100),
    departamento VARCHAR(50),
    provincia VARCHAR(50),
    distrito VARCHAR(50),
    categoria VARCHAR(50),
    latitud DECIMAL(15,12),
    longitud DECIMAL(15,12),
    estado VARCHAR(50),
    enlace TEXT,
    fecha_registro TIMESTAMP,
    fecha_modificacion TIMESTAMP,
    tipo_ra1_dup VARCHAR(10)  -- columna duplicada al final del CSV
);

\copy temp_hospitales FROM :'csv_dir'/hospitales_202601231018.csv WITH (FORMAT csv, HEADER true, QUOTE '"', ENCODING 'UTF8');

-- Insertar con mapeo de columnas (id -> hospital_id)
INSERT INTO hospitales (hospital_id, cod_renaes, cod_ses, cod_eess, tipo_ra1, tipo, nombre, departamento, provincia, distrito, categoria, latitud, longitud, estado, enlace, fecha_registro, fecha_modificacion)
SELECT id, cod_renaes, cod_ses, cod_eess, tipo_ra1, tipo, nombre, departamento, provincia, distrito, categoria, latitud, longitud, estado, enlace, fecha_registro, fecha_modificacion
FROM temp_hospitales;

DROP TABLE temp_hospitales;

-- =====================================================
-- 9. ASIGNACIONES_USUARIOS
-- =====================================================
\echo 'Cargando asignaciones_usuarios...'
\copy asignaciones_usuarios(id, usuario_id, area_id, rol, estado, fecha_asignacion, fecha_registro, fecha_modificacion) FROM :'csv_dir'/asignaciones_usuarios_202601231018.csv WITH (FORMAT csv, HEADER true, QUOTE '"', ENCODING 'UTF8');

-- =====================================================
-- 10. ALERTAS
-- =====================================================
\echo 'Cargando alertas...'
\copy alertas(id, dispositivo_id, area_id, habitacion_id, codigo_cama, tipo_alerta, estado_alerta, fecha_registro, fecha_modificacion, tiempo_respuesta) FROM :'csv_dir'/alertas_202601231018.csv WITH (FORMAT csv, HEADER true, QUOTE '"', ENCODING 'UTF8');

-- =====================================================
-- ACTUALIZAR SECUENCIAS
-- =====================================================
\echo 'Actualizando secuencias...'

SELECT setval('usuarios_id_seq', COALESCE((SELECT MAX(id) FROM usuarios), 1));
SELECT setval('variables_id_seq', COALESCE((SELECT MAX(id) FROM variables), 1));
SELECT setval('areas_id_seq', COALESCE((SELECT MAX(id) FROM areas), 1));
SELECT setval('habitaciones_id_seq', COALESCE((SELECT MAX(id) FROM habitaciones), 1));
SELECT setval('camas_id_seq', COALESCE((SELECT MAX(id) FROM camas), 1));
SELECT setval('camas_essi_id_seq', COALESCE((SELECT MAX(id) FROM camas_essi), 1));
SELECT setval('esp32_dispositivos_id_seq', COALESCE((SELECT MAX(id) FROM esp32_dispositivos), 1));
SELECT setval('hospitales_hospital_id_seq', COALESCE((SELECT MAX(hospital_id) FROM hospitales), 1));
SELECT setval('asignaciones_usuarios_id_seq', COALESCE((SELECT MAX(id) FROM asignaciones_usuarios), 1));
SELECT setval('alertas_id_seq', COALESCE((SELECT MAX(id) FROM alertas), 1));

COMMIT;

-- =====================================================
-- VERIFICAR CARGA
-- =====================================================
\echo ''
\echo '=========================================='
\echo 'RESUMEN DE DATOS CARGADOS'
\echo '=========================================='

SELECT 'usuarios' AS tabla, COUNT(*) AS registros FROM usuarios
UNION ALL SELECT 'variables', COUNT(*) FROM variables
UNION ALL SELECT 'areas', COUNT(*) FROM areas
UNION ALL SELECT 'habitaciones', COUNT(*) FROM habitaciones
UNION ALL SELECT 'camas', COUNT(*) FROM camas
UNION ALL SELECT 'camas_essi', COUNT(*) FROM camas_essi
UNION ALL SELECT 'esp32_dispositivos', COUNT(*) FROM esp32_dispositivos
UNION ALL SELECT 'hospitales', COUNT(*) FROM hospitales
UNION ALL SELECT 'asignaciones_usuarios', COUNT(*) FROM asignaciones_usuarios
UNION ALL SELECT 'alertas', COUNT(*) FROM alertas
ORDER BY tabla;

\echo ''
\echo 'Carga completada!'
\echo ''
