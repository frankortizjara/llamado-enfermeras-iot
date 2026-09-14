#!/bin/bash
# =====================================================
# Script para limpiar BD y cargar datos desde CSV
# =====================================================
# Uso: ./cargar_datos.sh
# =====================================================

# Configuración (del archivo .env)
DB_NAME="sistema_enfermeras"
DB_USER="postgres"
DB_HOST="localhost"
DB_PORT="5432"
export PGPASSWORD="admin"

# Ruta a los archivos CSV (relativa al script)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CSV_DIR="$SCRIPT_DIR/csv"

echo ""
echo "=========================================="
echo "CARGA DE DATOS - Sistema Llamado Enfermeras"
echo "=========================================="
echo ""
echo "Base de datos: $DB_NAME"
echo "Ruta CSV: $CSV_DIR"
echo ""

# Verificar que existen los archivos CSV
if [ ! -d "$CSV_DIR" ]; then
    echo "ERROR: No se encuentra el directorio de CSV: $CSV_DIR"
    exit 1
fi

# Verificar conexión a la base de datos
echo "Verificando conexión a la base de datos..."
if ! psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -c "SELECT 1" > /dev/null 2>&1; then
    echo "ERROR: No se puede conectar a la base de datos"
    echo "Verifica las credenciales y que PostgreSQL esté corriendo"
    exit 1
fi

echo "Conexión exitosa!"
echo ""

# Confirmar antes de proceder
read -p "¿Deseas BORRAR todos los datos actuales y cargar los CSV? (s/n): " confirm
if [ "$confirm" != "s" ] && [ "$confirm" != "S" ]; then
    echo "Operación cancelada"
    exit 0
fi

echo ""
echo "Limpiando base de datos..."

# Ejecutar limpieza
psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME << 'EOSQL'
BEGIN;

-- Deshabilitar constraints temporalmente
SET session_replication_role = 'replica';

-- Limpiar tablas
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

-- Rehabilitar constraints
SET session_replication_role = 'origin';

COMMIT;
EOSQL

if [ $? -ne 0 ]; then
    echo "ERROR: Falló la limpieza de la base de datos"
    exit 1
fi

echo "Base de datos limpiada"
echo ""
echo "Cargando datos desde CSV..."

# Cargar datos usando el script SQL
psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -f "$SCRIPT_DIR/09_load_csv_data.sql"

if [ $? -ne 0 ]; then
    echo "ERROR: Falló la carga de datos"
    exit 1
fi

echo ""
echo "=========================================="
echo "CARGA COMPLETADA EXITOSAMENTE"
echo "=========================================="
echo ""
echo "Ahora puedes:"
echo "1. Reiniciar el backend: cd ../.. && npm start"
echo "2. Recargar el frontend en el navegador"
echo ""
