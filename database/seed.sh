#!/bin/sh
# =============================================================================
# Carga de datos iniciales desde CSV — Sistema de Llamado de Enfermeras
# =============================================================================
# Carga en la BD los CSV exportados del servidor del piloto (database/seed/).
#
#   - Se ejecuta SOBRE el esquema que ya crearon las migraciones.
#   - REEMPLAZA el contenido de las tablas que tienen CSV (TRUNCATE + COPY).
#     Las tablas sin CSV no se tocan.
#   - Respeta el orden de llaves foraneas y ademas desactiva los triggers
#     durante la carga, asi que el orden de los archivos no puede romperla.
#   - Al terminar REAJUSTA TODAS LAS SECUENCIAS. Sin esto, el primer INSERT
#     del sistema chocaria con los IDs ya cargados.
#   - Todo va en UNA transaccion: si algo falla, no queda nada a medias.
#
# Variables requeridas: PGHOST, PGPORT, PGUSER, PGPASSWORD, PGDATABASE
# =============================================================================
set -eu

SEED_DIR="${SEED_DIR:-/seed}"
log() { echo "[seed] $*"; }

# Orden por llaves foraneas (hospitales antes que areas, etc.)
TABLAS="hospitales usuarios areas servicios_hospitalarios variables \
habitaciones camas camas_essi esp32_dispositivos dispositivo_eventos \
alertas historial_alertas historial_notas historial_ocupacion \
asignaciones_usuarios avisos cumpleanos efemerides config_tv \
controles_rf pantallas_tv"

[ -d "$SEED_DIR" ] || { log "ERROR: no existe $SEED_DIR"; exit 1; }

log "Esperando a PostgreSQL en ${PGHOST}:${PGPORT}..."
i=0
until pg_isready -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$PGDATABASE" >/dev/null 2>&1; do
    i=$((i + 1)); [ "$i" -ge 60 ] && { log "ERROR: PostgreSQL no respondio"; exit 1; }
    sleep 1
done

# Verificar que el esquema existe (las migraciones deben haber corrido antes)
if ! psql -tAq -c "SELECT 1 FROM pg_tables WHERE schemaname='public' AND tablename='alertas'" | grep -q 1; then
    log "ERROR: el esquema no existe. Corre las migraciones primero (make migrate)."
    exit 1
fi

# ---------------------------------------------------------------------------
# Construir el script de carga
# ---------------------------------------------------------------------------
SQL=$(mktemp)
{
    echo "BEGIN;"
    echo "SET session_replication_role = replica;"   # desactiva FK/triggers durante la carga

    # Vaciar las tablas que vamos a cargar.
    # Se usa DELETE y no TRUNCATE ... CASCADE a proposito: CASCADE tambien
    # vaciaria tablas que NO tienen CSV (p.ej. configuracion_sistema, que la
    # siembra la migracion 21) y perderiamos esa configuracion.
    # Con session_replication_role=replica el DELETE no dispara las FK.
    for t in $(echo "$TABLAS" | tr ' ' '\n' | tac); do
        [ -f "$SEED_DIR/$t.csv" ] || continue
        echo "DELETE FROM public.$t;"
    done

    # COPY de cada tabla, con la lista de columnas tomada del encabezado del CSV
    for t in $TABLAS; do
        f="$SEED_DIR/$t.csv"
        [ -f "$f" ] || continue
        # Se cita cada columna para preservar mayusculas ("codHabCama"):
        # sin comillas PostgreSQL las pasaria a minusculas y no encontraria la columna.
        cols=$(head -1 "$f" | tr -d '\r"' | tr ',' '\n' | sed 's/^ *//; s/ *$//; s/.*/"&"/' | paste -sd, -)
        echo "\\echo   cargando $t"
        echo "\\copy public.$t ($cols) FROM '$f' WITH (FORMAT csv, HEADER true, NULL '')"
    done

    echo "SET session_replication_role = DEFAULT;"

    # Reajuste de TODAS las secuencias ligadas a columnas
    cat <<'SQLBLOCK'
DO $$
DECLARE r RECORD; maxid BIGINT; n INT := 0;
BEGIN
  FOR r IN
    SELECT s.relname AS seq, t.relname AS tabla, a.attname AS col
    FROM pg_class s
    JOIN pg_depend d   ON d.objid = s.oid AND d.classid = 'pg_class'::regclass AND d.deptype = 'a'
    JOIN pg_class t    ON t.oid = d.refobjid
    JOIN pg_attribute a ON a.attrelid = t.oid AND a.attnum = d.refobjsubid
    JOIN pg_namespace n2 ON n2.oid = s.relnamespace
    WHERE s.relkind = 'S' AND n2.nspname = 'public'
  LOOP
    EXECUTE format('SELECT COALESCE(MAX(%I),0) FROM public.%I', r.col, r.tabla) INTO maxid;
    EXECUTE format('SELECT setval(%L, %s, %s)', 'public.'||r.seq, GREATEST(maxid,1),
                   CASE WHEN maxid > 0 THEN 'true' ELSE 'false' END);
    n := n + 1;
  END LOOP;
  RAISE NOTICE 'Secuencias reajustadas: %', n;
END $$;
SQLBLOCK

    echo "COMMIT;"
} > "$SQL"

log "Cargando datos desde $SEED_DIR ..."
psql -v ON_ERROR_STOP=1 -q -f "$SQL"
rm -f "$SQL"

# ---------------------------------------------------------------------------
# Resumen
# ---------------------------------------------------------------------------
log "=============================================="
log "Filas cargadas:"
for t in $TABLAS; do
    [ -f "$SEED_DIR/$t.csv" ] || continue
    c=$(psql -tAq -c "SELECT count(*) FROM public.$t")
    printf "[seed]   %-26s %s\n" "$t" "$c"
done
log "=============================================="
log "Carga completada."
