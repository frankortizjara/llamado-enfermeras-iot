-- =====================================================
-- SCRIPT: Limpiar base de datos y cargar datos desde CSV
-- =====================================================
-- Este script:
-- 1. Limpia todas las tablas
-- 2. Resetea las secuencias
-- 3. Carga datos desde los archivos CSV
--
-- IMPORTANTE: Ejecutar desde psql con la ruta correcta a los CSVs
-- Ejemplo: psql -U tu_usuario -d sistema_enfermeras -f 08_reset_and_load_csv.sql
-- =====================================================

-- Configurar cliente
SET client_encoding = 'UTF8';

-- =====================================================
-- PASO 1: Deshabilitar triggers y constraints temporalmente
-- =====================================================
BEGIN;

-- Deshabilitar triggers
ALTER TABLE alertas DISABLE TRIGGER ALL;
ALTER TABLE asignaciones_usuarios DISABLE TRIGGER ALL;
ALTER TABLE camas DISABLE TRIGGER ALL;
ALTER TABLE habitaciones DISABLE TRIGGER ALL;
ALTER TABLE areas DISABLE TRIGGER ALL;

-- =====================================================
-- PASO 2: Limpiar todas las tablas (orden por dependencias)
-- =====================================================
TRUNCATE TABLE alertas CASCADE;
TRUNCATE TABLE asignaciones_usuarios CASCADE;
TRUNCATE TABLE camas CASCADE;
TRUNCATE TABLE habitaciones CASCADE;
TRUNCATE TABLE areas CASCADE;
TRUNCATE TABLE camas_essi CASCADE;
TRUNCATE TABLE esp32_dispositivos CASCADE;
TRUNCATE TABLE usuarios CASCADE;
TRUNCATE TABLE hospitales CASCADE;
TRUNCATE TABLE variables CASCADE;

RAISE NOTICE 'Tablas limpiadas correctamente';

-- =====================================================
-- PASO 3: Resetear secuencias
-- =====================================================
ALTER SEQUENCE IF EXISTS alertas_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS asignaciones_usuarios_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS camas_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS habitaciones_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS areas_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS camas_essi_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS esp32_dispositivos_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS usuarios_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS hospitales_hospital_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS variables_id_seq RESTART WITH 1;

RAISE NOTICE 'Secuencias reseteadas';

COMMIT;

-- =====================================================
-- NOTAS SOBRE CARGA DE CSV
-- =====================================================
-- Los siguientes comandos COPY deben ejecutarse desde psql
-- usando \copy o desde un script bash con rutas absolutas.
--
-- La ruta de los CSV debe ser accesible por el servidor PostgreSQL
-- si usas COPY, o por el cliente psql si usas \copy.
-- =====================================================

\echo ''
\echo '=========================================='
\echo 'BASE DE DATOS LIMPIADA CORRECTAMENTE'
\echo '=========================================='
\echo ''
\echo 'Ahora ejecuta el script de carga:'
\echo '  psql -d sistema_enfermeras -f 09_load_csv_data.sql'
\echo ''
\echo 'O carga manualmente usando los comandos \\copy'
\echo 'que se muestran a continuacion...'
\echo ''
