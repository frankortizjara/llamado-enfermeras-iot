-- 1. Eliminar funciones existentes
DROP FUNCTION IF EXISTS sp_consultar_habitaciones_essi(VARCHAR);
DROP FUNCTION IF EXISTS sp_cargar_data_essi(VARCHAR,VARCHAR,VARCHAR,VARCHAR,VARCHAR,VARCHAR,VARCHAR,VARCHAR,VARCHAR,VARCHAR,VARCHAR);
DROP FUNCTION IF EXISTS sp_consultar_info_habitaciones();

-- 2. Crear función corregida
CREATE OR REPLACE FUNCTION public.sp_consultar_habitaciones_essi(
    codHabCama_input VARCHAR
)
RETURNS JSONB AS $$
DECLARE
    habitaciones_json JSONB := '[]'::jsonb;
    camas_json JSONB;
    habitacion RECORD;
    cama RECORD;
BEGIN
    FOR habitacion IN
        SELECT codhab
        FROM camas_essi
        WHERE codhabcama = codHabCama_input
        GROUP BY codhab
        ORDER BY codhab
    LOOP
        camas_json := '[]'::jsonb;
        FOR cama IN
            SELECT id, codcama, nrodocidepac, nrohisclicas, tipodocidepac, apenompac, nota, fecha_nota
            FROM camas_essi c
            WHERE c.codhab = habitacion.codhab AND c.codhabcama = codHabCama_input AND c.estado = TRUE
            ORDER BY codcama
        LOOP
            camas_json := camas_json || jsonb_build_object(
                'id', cama.id,
                'nombre', cama.codcama,
                'paciente', cama.apenompac,
                'nota', cama.nota,
                'fecha_nota', cama.fecha_nota
            );
        END LOOP;
        habitaciones_json := habitaciones_json || jsonb_build_object(
            'nombre', habitacion.codhab,
            'camas', camas_json
        );
    END LOOP;

    RETURN jsonb_build_object('estado', 'success', 'codigo', 200, 'mensaje', habitaciones_json);
EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object('estado', 'error', 'codigo', 500, 'mensaje', SQLERRM);
END;
$$ LANGUAGE plpgsql;





SELECT sp_consultar_habitaciones_essi('UCI');
