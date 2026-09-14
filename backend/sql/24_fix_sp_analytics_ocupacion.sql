-- =====================================================
-- MIGRACION 24: Fix sp_analytics_ocupacion
-- =====================================================
-- Corrige el SP para manejar tablas vacias correctamente
-- =====================================================

SET search_path TO public;

CREATE OR REPLACE FUNCTION public.sp_analytics_ocupacion(
    pi_area_id INT,
    pi_fecha_inicio TIMESTAMP,
    pi_fecha_fin TIMESTAMP
)
RETURNS JSONB AS $$
DECLARE
    resultado JSONB;
    por_dia JSONB;
    v_area_nombre VARCHAR(255);
    v_total_ingresos INT;
    v_total_egresos INT;
    v_ocupacion_actual INT;
    v_total_camas INT;
BEGIN
    BEGIN
        -- Obtener nombre del area
        SELECT nombre INTO v_area_nombre
        FROM public.areas
        WHERE id = pi_area_id;

        -- Si no se encuentra el area, retornar error
        IF v_area_nombre IS NULL THEN
            RETURN jsonb_build_object('estado', 'error', 'codigo', 404, 'mensaje', 'Area no encontrada');
        END IF;

        -- Contar ingresos
        SELECT COUNT(*) INTO v_total_ingresos
        FROM public.historial_ocupacion
        WHERE codhabcama = v_area_nombre
          AND accion = 'INGRESO'
          AND fecha_evento BETWEEN pi_fecha_inicio AND pi_fecha_fin;

        -- Contar egresos
        SELECT COUNT(*) INTO v_total_egresos
        FROM public.historial_ocupacion
        WHERE codhabcama = v_area_nombre
          AND accion = 'EGRESO'
          AND fecha_evento BETWEEN pi_fecha_inicio AND pi_fecha_fin;

        -- Ocupacion actual (camas con paciente)
        SELECT COUNT(*) INTO v_ocupacion_actual
        FROM public.camas_essi
        WHERE "codHabCama" = v_area_nombre
          AND estado = TRUE
          AND "apeNomPac" IS NOT NULL
          AND "apeNomPac" != '';

        -- Total de camas
        SELECT COUNT(*) INTO v_total_camas
        FROM public.camas_essi
        WHERE "codHabCama" = v_area_nombre
          AND estado = TRUE;

        -- Construir resultado
        resultado := jsonb_build_object(
            'total_ingresos', COALESCE(v_total_ingresos, 0),
            'total_egresos', COALESCE(v_total_egresos, 0),
            'ocupacion_actual', COALESCE(v_ocupacion_actual, 0),
            'total_camas', COALESCE(v_total_camas, 0)
        );

        -- Movimientos por dia
        SELECT COALESCE(jsonb_agg(row_data ORDER BY fecha), '[]'::jsonb) INTO por_dia
        FROM (
            SELECT jsonb_build_object(
                'fecha', fecha_evento::date,
                'ingresos', COUNT(*) FILTER (WHERE accion = 'INGRESO'),
                'egresos', COUNT(*) FILTER (WHERE accion = 'EGRESO')
            ) AS row_data,
            fecha_evento::date AS fecha
            FROM public.historial_ocupacion
            WHERE codhabcama = v_area_nombre
              AND fecha_evento BETWEEN pi_fecha_inicio AND pi_fecha_fin
            GROUP BY fecha_evento::date
        ) sub;

        resultado := resultado || jsonb_build_object('por_dia', COALESCE(por_dia, '[]'::jsonb));

        RETURN jsonb_build_object('estado', 'success', 'codigo', 200, 'mensaje', resultado);
    EXCEPTION
        WHEN OTHERS THEN
            RETURN jsonb_build_object('estado', 'error', 'codigo', 500, 'mensaje', SQLERRM);
    END;
END;
$$ LANGUAGE plpgsql;

-- Verificacion
DO $$
BEGIN
    RAISE NOTICE 'Migracion 24: sp_analytics_ocupacion corregido';
END $$;
