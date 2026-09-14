-- =====================================================
-- MIGRACION 23: Stored procedures de analytics
-- =====================================================
-- 4 SPs de solo lectura para el dashboard de analytics:
--   1. sp_analytics_tiempos_respuesta
--   2. sp_analytics_historial_notas
--   3. sp_analytics_ocupacion
--   4. sp_analytics_frecuencia_alertas
-- =====================================================

SET search_path TO public;

-- =====================================================
-- 1. Tiempos de respuesta de alertas
-- =====================================================

CREATE OR REPLACE FUNCTION public.sp_analytics_tiempos_respuesta(
    pi_area_id INT,
    pi_fecha_inicio TIMESTAMP,
    pi_fecha_fin TIMESTAMP
)
RETURNS JSONB AS $$
DECLARE
    resultado JSONB;
    por_habitacion JSONB;
BEGIN
    BEGIN
        -- Resumen general
        SELECT jsonb_build_object(
            'tiempo_promedio_minutos', COALESCE(ROUND(EXTRACT(EPOCH FROM AVG(tiempo_respuesta)) / 60, 2), 0),
            'tiempo_minimo_minutos', COALESCE(ROUND(EXTRACT(EPOCH FROM MIN(tiempo_respuesta)) / 60, 2), 0),
            'tiempo_maximo_minutos', COALESCE(ROUND(EXTRACT(EPOCH FROM MAX(tiempo_respuesta)) / 60, 2), 0),
            'total_alertas', COUNT(*)
        ) INTO resultado
        FROM public.historial_alertas
        WHERE area_id = pi_area_id
          AND fecha_alerta BETWEEN pi_fecha_inicio AND pi_fecha_fin;

        -- Por habitacion
        SELECT COALESCE(jsonb_agg(row_data), '[]'::jsonb) INTO por_habitacion
        FROM (
            SELECT jsonb_build_object(
                'habitacion_id', habitacion_id,
                'tiempo_promedio_minutos', ROUND(EXTRACT(EPOCH FROM AVG(tiempo_respuesta)) / 60, 2),
                'total_alertas', COUNT(*),
                'con_usuario', COUNT(usuario_respuesta_id),
                'sin_usuario', COUNT(*) - COUNT(usuario_respuesta_id)
            ) AS row_data
            FROM public.historial_alertas
            WHERE area_id = pi_area_id
              AND fecha_alerta BETWEEN pi_fecha_inicio AND pi_fecha_fin
            GROUP BY habitacion_id
            ORDER BY habitacion_id
        ) sub;

        resultado := resultado || jsonb_build_object('por_habitacion', por_habitacion);

        RETURN jsonb_build_object('estado', 'success', 'codigo', 200, 'mensaje', resultado);
    EXCEPTION
        WHEN OTHERS THEN
            RETURN jsonb_build_object('estado', 'error', 'codigo', 500, 'mensaje', SQLERRM);
    END;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- 2. Historial de notas
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
BEGIN
    BEGIN
        -- Filtrar notas cuya cama_essi pertenece al area via habitaciones
        -- historial_notas.cama_essi_id -> camas_essi.id -> camas_essi."codHab" -> habitaciones.nombre -> habitaciones.area_id

        -- Resumen por accion
        SELECT COALESCE(jsonb_agg(row_data), '[]'::jsonb) INTO por_accion
        FROM (
            SELECT jsonb_build_object(
                'accion', hn.accion,
                'total', COUNT(*)
            ) AS row_data
            FROM public.historial_notas hn
            JOIN public.camas_essi ce ON hn.cama_essi_id = ce.id
            JOIN public.habitaciones h ON h.nombre::text = ce."codHab" AND h.area_id = pi_area_id
            WHERE hn.fecha_registro BETWEEN pi_fecha_inicio AND pi_fecha_fin
            GROUP BY hn.accion
            ORDER BY hn.accion
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
            JOIN public.camas_essi ce ON hn.cama_essi_id = ce.id
            JOIN public.habitaciones h ON h.nombre::text = ce."codHab" AND h.area_id = pi_area_id
            LEFT JOIN public.usuarios u ON hn.usuario_id = u.id
            WHERE hn.fecha_registro BETWEEN pi_fecha_inicio AND pi_fecha_fin
            GROUP BY hn.usuario_id, u.nombre
            ORDER BY COUNT(*) DESC
        ) sub;

        -- Total general
        resultado := jsonb_build_object(
            'total', (
                SELECT COUNT(*)
                FROM public.historial_notas hn
                JOIN public.camas_essi ce ON hn.cama_essi_id = ce.id
                JOIN public.habitaciones h ON h.nombre::text = ce."codHab" AND h.area_id = pi_area_id
                WHERE hn.fecha_registro BETWEEN pi_fecha_inicio AND pi_fecha_fin
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
-- 3. Ocupacion de camas
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
BEGIN
    BEGIN
        -- Resumen general: filtrar via habitaciones del area
        SELECT jsonb_build_object(
            'total_ingresos', COUNT(*) FILTER (WHERE ho.accion = 'INGRESO'),
            'total_egresos', COUNT(*) FILTER (WHERE ho.accion = 'EGRESO'),
            'ocupacion_actual', (
                SELECT COUNT(*)
                FROM public.camas_essi ce
                JOIN public.habitaciones h ON h.nombre::text = ce."codHab" AND h.area_id = pi_area_id
                WHERE ce.estado = TRUE
                  AND ce."apeNomPac" != ''
            ),
            'total_camas', (
                SELECT COUNT(*)
                FROM public.camas_essi ce
                JOIN public.habitaciones h ON h.nombre::text = ce."codHab" AND h.area_id = pi_area_id
                WHERE ce.estado = TRUE
            )
        ) INTO resultado
        FROM public.historial_ocupacion ho
        JOIN public.habitaciones h ON h.nombre::text = ho.codhab AND h.area_id = pi_area_id
        WHERE ho.fecha_evento BETWEEN pi_fecha_inicio AND pi_fecha_fin;

        -- Movimientos por dia
        SELECT COALESCE(jsonb_agg(row_data ORDER BY fecha), '[]'::jsonb) INTO por_dia
        FROM (
            SELECT jsonb_build_object(
                'fecha', ho.fecha_evento::date,
                'ingresos', COUNT(*) FILTER (WHERE ho.accion = 'INGRESO'),
                'egresos', COUNT(*) FILTER (WHERE ho.accion = 'EGRESO')
            ) AS row_data,
            ho.fecha_evento::date AS fecha
            FROM public.historial_ocupacion ho
            JOIN public.habitaciones h ON h.nombre::text = ho.codhab AND h.area_id = pi_area_id
            WHERE ho.fecha_evento BETWEEN pi_fecha_inicio AND pi_fecha_fin
            GROUP BY ho.fecha_evento::date
        ) sub;

        resultado := resultado || jsonb_build_object('por_dia', por_dia);

        RETURN jsonb_build_object('estado', 'success', 'codigo', 200, 'mensaje', resultado);
    EXCEPTION
        WHEN OTHERS THEN
            RETURN jsonb_build_object('estado', 'error', 'codigo', 500, 'mensaje', SQLERRM);
    END;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- 4. Frecuencia de alertas
-- =====================================================

CREATE OR REPLACE FUNCTION public.sp_analytics_frecuencia_alertas(
    pi_area_id INT,
    pi_fecha_inicio TIMESTAMP,
    pi_fecha_fin TIMESTAMP
)
RETURNS JSONB AS $$
DECLARE
    resultado JSONB;
    por_hora JSONB;
    por_dia_semana JSONB;
    por_habitacion JSONB;
BEGIN
    BEGIN
        -- Total general
        SELECT jsonb_build_object(
            'total_alertas', COUNT(*),
            'alertas_tipo_1', COUNT(*) FILTER (WHERE tipo_alerta = 1),
            'alertas_tipo_2', COUNT(*) FILTER (WHERE tipo_alerta = 2)
        ) INTO resultado
        FROM public.historial_alertas
        WHERE area_id = pi_area_id
          AND fecha_alerta BETWEEN pi_fecha_inicio AND pi_fecha_fin;

        -- Por hora del dia
        SELECT COALESCE(jsonb_agg(row_data ORDER BY hora), '[]'::jsonb) INTO por_hora
        FROM (
            SELECT jsonb_build_object(
                'hora', EXTRACT(HOUR FROM fecha_alerta)::int,
                'total', COUNT(*)
            ) AS row_data,
            EXTRACT(HOUR FROM fecha_alerta)::int AS hora
            FROM public.historial_alertas
            WHERE area_id = pi_area_id
              AND fecha_alerta BETWEEN pi_fecha_inicio AND pi_fecha_fin
            GROUP BY EXTRACT(HOUR FROM fecha_alerta)::int
        ) sub;

        -- Por dia de la semana (0=domingo, 6=sabado)
        SELECT COALESCE(jsonb_agg(row_data ORDER BY dia), '[]'::jsonb) INTO por_dia_semana
        FROM (
            SELECT jsonb_build_object(
                'dia', EXTRACT(DOW FROM fecha_alerta)::int,
                'nombre', CASE EXTRACT(DOW FROM fecha_alerta)::int
                    WHEN 0 THEN 'Domingo'
                    WHEN 1 THEN 'Lunes'
                    WHEN 2 THEN 'Martes'
                    WHEN 3 THEN 'Miercoles'
                    WHEN 4 THEN 'Jueves'
                    WHEN 5 THEN 'Viernes'
                    WHEN 6 THEN 'Sabado'
                END,
                'total', COUNT(*)
            ) AS row_data,
            EXTRACT(DOW FROM fecha_alerta)::int AS dia
            FROM public.historial_alertas
            WHERE area_id = pi_area_id
              AND fecha_alerta BETWEEN pi_fecha_inicio AND pi_fecha_fin
            GROUP BY EXTRACT(DOW FROM fecha_alerta)::int
        ) sub;

        -- Por habitacion
        SELECT COALESCE(jsonb_agg(row_data), '[]'::jsonb) INTO por_habitacion
        FROM (
            SELECT jsonb_build_object(
                'habitacion_id', habitacion_id,
                'total', COUNT(*),
                'tipo_1', COUNT(*) FILTER (WHERE tipo_alerta = 1),
                'tipo_2', COUNT(*) FILTER (WHERE tipo_alerta = 2)
            ) AS row_data
            FROM public.historial_alertas
            WHERE area_id = pi_area_id
              AND fecha_alerta BETWEEN pi_fecha_inicio AND pi_fecha_fin
            GROUP BY habitacion_id
            ORDER BY COUNT(*) DESC
        ) sub;

        resultado := resultado || jsonb_build_object(
            'por_hora', por_hora,
            'por_dia_semana', por_dia_semana,
            'por_habitacion', por_habitacion
        );

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
    RAISE NOTICE 'Migracion 23: 4 SPs de analytics creados';
    RAISE NOTICE '  - sp_analytics_tiempos_respuesta';
    RAISE NOTICE '  - sp_analytics_historial_notas';
    RAISE NOTICE '  - sp_analytics_ocupacion';
    RAISE NOTICE '  - sp_analytics_frecuencia_alertas';
END $$;
