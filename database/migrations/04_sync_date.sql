-- =====================================================
-- UPDATE: sp_consultar_habitaciones_essi
-- Agrega ultimaSincronizacion al response
-- CORREGIDO: usa nombres de columna con comillas ("codHabCama", etc.)
-- =====================================================

DROP FUNCTION IF EXISTS public.sp_consultar_habitaciones_essi(VARCHAR);

CREATE OR REPLACE FUNCTION public.sp_consultar_habitaciones_essi(codHabCama_input VARCHAR)
RETURNS JSONB AS $$
DECLARE
    habitaciones_json JSONB := '[]'::jsonb;
    camas_json JSONB;
    habitacion RECORD;
    cama RECORD;
    ultima_sync TIMESTAMP;
BEGIN
    -- Obtener fecha de ultima sincronizacion
    SELECT MAX(fecha_registro) INTO ultima_sync
    FROM public.camas_essi
    WHERE "codHabCama" = codHabCama_input
    AND estado = TRUE;

    FOR habitacion IN SELECT "codHab" FROM camas_essi WHERE "codHabCama" = codHabCama_input GROUP BY "codHab" ORDER BY "codHab" LOOP
        camas_json := '[]'::jsonb;
        FOR cama IN
            SELECT id, "codCama", "nroDocIdePac", "nroHisCliCas", "tipoDocIdePac", "apeNomPac", nota, fecha_nota
            FROM camas_essi c WHERE c."codHab" = habitacion."codHab" AND c."codHabCama" = codHabCama_input AND c.estado = TRUE
            ORDER BY "codCama"
        LOOP
            camas_json := camas_json || jsonb_build_object('id', cama.id, 'nombre', cama."codCama", 'paciente', cama."apeNomPac", 'nota', cama.nota, 'fecha_nota', cama.fecha_nota);
        END LOOP;
        habitaciones_json := habitaciones_json || jsonb_build_object('nombre', habitacion."codHab", 'camas', camas_json);
    END LOOP;

    RETURN jsonb_build_object(
        'estado', 'success',
        'codigo', 200,
        'mensaje', jsonb_build_object(
            'habitaciones', habitaciones_json,
            'ultimaSincronizacion', COALESCE(TO_CHAR(ultima_sync, 'DD/MM/YYYY HH12:MI AM'), 'Sin datos')
        )
    );
EXCEPTION
    WHEN OTHERS THEN RETURN jsonb_build_object('estado', 'error', 'codigo', 500, 'mensaje', SQLERRM);
END;
$$ LANGUAGE plpgsql;
