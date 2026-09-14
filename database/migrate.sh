#!/bin/sh
# =============================================================================
# Migration runner idempotente para PostgreSQL
# =============================================================================
# - Espera a que PostgreSQL este listo.
# - Crea (si no existe) la tabla schema_migrations para llevar control.
# - Aplica SOLO los archivos .sql de /migrations/ que aun no se hayan aplicado,
#   en orden alfabetico, cada uno en una transaccion.
# - No borra datos. No re-ejecuta migraciones ya aplicadas.
#
# Variables de entorno requeridas:
#   PGHOST, PGPORT, PGUSER, PGPASSWORD, PGDATABASE
# =============================================================================
set -eu

MIGRATIONS_DIR="${MIGRATIONS_DIR:-/migrations}"
MAX_WAIT="${MAX_WAIT:-60}"

log() { echo "[migrate] $*"; }

log "Esperando a PostgreSQL en ${PGHOST}:${PGPORT}..."
i=0
until pg_isready -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$PGDATABASE" >/dev/null 2>&1; do
    i=$((i + 1))
    if [ "$i" -ge "$MAX_WAIT" ]; then
        log "ERROR: PostgreSQL no respondio tras ${MAX_WAIT}s"
        exit 1
    fi
    sleep 1
done
log "PostgreSQL listo."

# Crear tabla de control si no existe
psql -v ON_ERROR_STOP=1 -q <<'SQL'
CREATE TABLE IF NOT EXISTS public.schema_migrations (
    filename   TEXT PRIMARY KEY,
    applied_at TIMESTAMP NOT NULL DEFAULT NOW(),
    checksum   TEXT
);
SQL

applied_count=0
skipped_count=0
failed_count=0

for f in "$MIGRATIONS_DIR"/*.sql; do
    [ -e "$f" ] || { log "No hay archivos .sql en $MIGRATIONS_DIR"; break; }
    fname=$(basename "$f")

    already=$(psql -tAq -c "SELECT 1 FROM public.schema_migrations WHERE filename = '${fname}' LIMIT 1;" 2>/dev/null || echo "")

    if [ "$already" = "1" ]; then
        skipped_count=$((skipped_count + 1))
        continue
    fi

    checksum=$(sha256sum "$f" | awk '{print $1}')
    log "Aplicando: $fname  (sha256=${checksum%????????????????????????????????????????????????????????})"

    # Ejecutar migracion + registro en una sola transaccion
    if psql -v ON_ERROR_STOP=1 -q --single-transaction \
        -f "$f" \
        -c "INSERT INTO public.schema_migrations (filename, checksum) VALUES ('${fname}', '${checksum}');" \
        >/dev/null; then
        applied_count=$((applied_count + 1))
        log "  OK"
    else
        failed_count=$((failed_count + 1))
        log "  ERROR aplicando $fname — deteniendo."
        exit 1
    fi
done

log "=============================================="
log "Resumen: aplicadas=${applied_count}  ya-presentes=${skipped_count}  fallidas=${failed_count}"
log "=============================================="

if [ "$applied_count" -eq 0 ] && [ "$skipped_count" -gt 0 ]; then
    log "La base de datos ya esta al dia. Nada que hacer."
fi
