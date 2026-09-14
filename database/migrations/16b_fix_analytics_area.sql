-- =====================================================
-- MIGRACION 38: Fix filtro de area en SPs de analytics
-- =====================================================
-- Problema: Los SPs de ocupacion y notas intentaban obtener
-- codHabCama via JOIN con la tabla habitaciones, pero esa
-- tabla puede estar vacia.
--
-- La relacion real entre area_id y codHabCama está en:
-- asignaciones_usuarios.permisos->'config_essi'->>'codHabCama'
--
-- Solucion: Obtener codHabCama desde asignaciones_usuarios
-- =====================================================

SET search_path TO public;

-- =====================================================
-- 1. FIX: sp_analytics_ocupacion
-- =====================================================

CREATE OR REPLACE FUNCTION public.sp_analytics_ocupacion(
    pi_area_id INT,
    pi_fecha_inicio TIMESTAMP,
    pi_fecha_fin TIMESTAMP
)
RETURNS JSONB AS $$
DECLARE
    resultado JSONB;
    por_dia JSONB;
    v_codhabcama VARCHAR(255);
    v_total_ingresos INT := 0;
    v_total_egresos INT := 0;
    v_ocupacion_actual INT := 0;
    v_total_camas INT := 0;
BEGIN
    BEGIN
        -- Obtener codHabCama desde config_essi de usuarios asignados al area
        SELECT permisos->'config_essi'->>'codHabCama' INTO v_codhabcama
        FROM public.asignaciones_usuarios
        WHERE area_id = pi_area_id
          AND estado = TRUE
          AND permisos->'config_essi'->>'codHabCama' IS NOT NULL
        LIMIT 1;

        -- Fallback: intentar via habitaciones si existe alguna
        IF v_codhabcama IS NULL THEN
            SELECT DISTINCT ce."codHabCama" INTO v_codhabcama
            FROM public.camas_essi ce
            JOIN public.habitaciones h ON h.nombre::text = ce."codHab" AND h.area_id = pi_area_id
            WHERE ce.estado = TRUE
            LIMIT 1;
        END IF;

        -- Si no se encuentra codHabCama, retornar valores por defecto
        IF v_codhabcama IS NULL THEN
            RETURN jsonb_build_object(
                'estado', 'success',
                'codigo', 200,
                'mensaje', jsonb_build_object(
                    'total_ingresos', 0,
                    'total_egresos', 0,
                    'ocupacion_actual', 0,
                    'total_camas', 0,
                    'por_dia', '[]'::jsonb
                )
            );
        END IF;

        -- Contar ingresos y egresos del historial
        SELECT
            COALESCE(COUNT(*) FILTER (WHERE accion = 'INGRESO'), 0),
            COALESCE(COUNT(*) FILTER (WHERE accion = 'EGRESO'), 0)
        INTO v_total_ingresos, v_total_egresos
        FROM public.historial_ocupacion
        WHERE codhabcama = v_codhabcama
          AND fecha_evento::date BETWEEN pi_fecha_inicio::date AND pi_fecha_fin::date;

        -- Contar ocupacion actual (camas con paciente)
        SELECT COALESCE(COUNT(*), 0) INTO v_ocupacion_actual
        FROM public.camas_essi
        WHERE "codHabCama" = v_codhabcama
          AND estado = TRUE
          AND COALESCE("apeNomPac", '') != '';

        -- Contar total de camas activas
        SELECT COALESCE(COUNT(*), 0) INTO v_total_camas
        FROM public.camas_essi
        WHERE "codHabCama" = v_codhabcama
          AND estado = TRUE;

        -- Construir resultado
        resultado := jsonb_build_object(
            'total_ingresos', v_total_ingresos,
            'total_egresos', v_total_egresos,
            'ocupacion_actual', v_ocupacion_actual,
            'total_camas', v_total_camas
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
            WHERE codhabcama = v_codhabcama
              AND fecha_evento::date BETWEEN pi_fecha_inicio::date AND pi_fecha_fin::date
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

-- =====================================================
-- 2. FIX: sp_analytics_historial_notas
-- =====================================================

CREATE OR REPLACE FUNCTION public.sp_analytics_historial_notas(
    pi_area_id INT,
    pi_fecha_inicio TIMESTAMP,
    pi_fecha_fin TIMESTAMP
)
RETURNS JSONB AS $$
DECLARE
    resultado JSONB;
    por_accion JSONB;
    por_usuario JSONB;
    v_codhabcama VARCHAR(255);
BEGIN
    BEGIN
        -- Obtener codHabCama desde config_essi de usuarios asignados al area
        SELECT permisos->'config_essi'->>'codHabCama' INTO v_codhabcama
        FROM public.asignaciones_usuarios
        WHERE area_id = pi_area_id
          AND estado = TRUE
          AND permisos->'config_essi'->>'codHabCama' IS NOT NULL
        LIMIT 1;

        -- Fallback: intentar via habitaciones si existe alguna
        IF v_codhabcama IS NULL THEN
            SELECT DISTINCT ce."codHabCama" INTO v_codhabcama
            FROM public.camas_essi ce
            JOIN public.habitaciones h ON h.nombre::text = ce."codHab" AND h.area_id = pi_area_id
            WHERE ce.estado = TRUE
            LIMIT 1;
        END IF;

        -- Resumen por accion (comparando solo fecha)
        SELECT COALESCE(jsonb_agg(row_data), '[]'::jsonb) INTO por_accion
        FROM (
            SELECT jsonb_build_object(
                'accion', accion,
                'total', COUNT(*)
            ) AS row_data
            FROM public.historial_notas
            WHERE codhabcama = v_codhabcama
              AND fecha_registro::date BETWEEN pi_fecha_inicio::date AND pi_fecha_fin::date
            GROUP BY accion
            ORDER BY accion
        ) sub;

        -- Resumen por usuario
        SELECT COALESCE(jsonb_agg(row_data), '[]'::jsonb) INTO por_usuario
        FROM (
            SELECT jsonb_build_object(
                'usuario_id', hn.usuario_id,
                'usuario_nombre', COALESCE(u.nombre, 'Sistema'),
                'total', COUNT(*)
            ) AS row_data
            FROM public.historial_notas hn
            LEFT JOIN public.usuarios u ON hn.usuario_id = u.id
            WHERE hn.codhabcama = v_codhabcama
              AND hn.fecha_registro::date BETWEEN pi_fecha_inicio::date AND pi_fecha_fin::date
            GROUP BY hn.usuario_id, u.nombre
            ORDER BY COUNT(*) DESC
        ) sub;

        -- Total general
        resultado := jsonb_build_object(
            'total', (
                SELECT COUNT(*)
                FROM public.historial_notas
                WHERE codhabcama = v_codhabcama
                  AND fecha_registro::date BETWEEN pi_fecha_inicio::date AND pi_fecha_fin::date
            ),
            'por_accion', por_accion,
            'por_usuario', por_usuario
        );

        RETURN jsonb_build_object('estado', 'success', 'codigo', 200, 'mensaje', resultado);
    EXCEPTION
        WHEN OTHERS THEN
            RETURN jsonb_build_object('estado', 'error', 'codigo', 500, 'mensaje', SQLERRM);
    END;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- Verificacion
-- =====================================================
DO $$
DECLARE
    v_test JSONB;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'MIGRACION 38: Fix filtro area analytics';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'SPs actualizados:';
    RAISE NOTICE '  - sp_analytics_ocupacion';
    RAISE NOTICE '  - sp_analytics_historial_notas';
    RAISE NOTICE '';
    RAISE NOTICE 'Ahora obtienen codHabCama via:';
    RAISE NOTICE '  1. asignaciones_usuarios.permisos->config_essi->codHabCama';
    RAISE NOTICE '  2. Fallback: JOIN camas_essi -> habitaciones';
    RAISE NOTICE '========================================';
END $$;
