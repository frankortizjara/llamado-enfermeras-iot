-- =====================================================
-- FIX: Comparacion de fechas en SPs de analytics
-- Problema: Las fechas se pasaban como YYYY-MM-DD que
-- PostgreSQL interpreta como 00:00:00, excluyendo
-- registros del mismo dia con hora > 00:00:00
-- Solucion: Usar ::date para comparar solo la fecha
-- =====================================================

SET search_path TO public;

-- =====================================================
-- PASO 0a: Crear tabla areas si no existe
-- =====================================================

CREATE TABLE IF NOT EXISTS public.areas (
    id SERIAL PRIMARY KEY,
    cod_ses INTEGER NOT NULL DEFAULT 0,
    nombre VARCHAR(255) NOT NULL,
    estado BOOLEAN DEFAULT TRUE,
    fecha_registro TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    fecha_modificacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insertar area por defecto si esta vacia
INSERT INTO public.areas (id, cod_ses, nombre, estado)
SELECT 1, 0, 'CIR1', TRUE
WHERE NOT EXISTS (SELECT 1 FROM public.areas WHERE id = 1);

-- =====================================================
-- PASO 0b: Crear tablas de historial si no existen
-- =====================================================

CREATE TABLE IF NOT EXISTS public.historial_alertas (
    id SERIAL PRIMARY KEY,
    alerta_id INT NOT NULL,
    dispositivo_id INT,
    area_id INT,
    habitacion_id INT,
    codigo_cama VARCHAR(50),
    tipo_alerta INT,
    tiempo_respuesta INTERVAL,
    usuario_respuesta_id INT,
    fecha_alerta TIMESTAMP NOT NULL,
    fecha_respuesta TIMESTAMP NOT NULL,
    fecha_registro TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_historial_alertas_area
    ON public.historial_alertas(area_id);
CREATE INDEX IF NOT EXISTS idx_historial_alertas_fecha
    ON public.historial_alertas(fecha_alerta);

CREATE TABLE IF NOT EXISTS public.historial_notas (
    id SERIAL PRIMARY KEY,
    cama_essi_id INT NOT NULL,
    codhabcama VARCHAR(255),
    codhab VARCHAR(255),
    codcama VARCHAR(255),
    paciente VARCHAR(255),
    nota_anterior VARCHAR(8) DEFAULT '',
    nota_nueva VARCHAR(8) DEFAULT '',
    fecha_nota_anterior VARCHAR(255) DEFAULT '',
    fecha_nota_nueva VARCHAR(255) DEFAULT '',
    accion VARCHAR(20) NOT NULL,
    usuario_id INT,
    fecha_registro TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_historial_notas_fecha
    ON public.historial_notas(fecha_registro);

CREATE TABLE IF NOT EXISTS public.historial_ocupacion (
    id SERIAL PRIMARY KEY,
    cama_essi_id INT,
    codhabcama VARCHAR(255),
    codhab VARCHAR(255),
    codcama VARCHAR(255),
    paciente VARCHAR(255),
    nrodocidepac VARCHAR(255),
    accion VARCHAR(20) NOT NULL,
    fecha_evento TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_historial_ocupacion_fecha
    ON public.historial_ocupacion(fecha_evento);

-- =====================================================
-- 1. FIX: sp_analytics_tiempos_respuesta
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
        -- Resumen general (comparando solo fecha, no hora)
        SELECT jsonb_build_object(
            'tiempo_promedio_minutos', COALESCE(ROUND(EXTRACT(EPOCH FROM AVG(tiempo_respuesta)) / 60, 2), 0),
            'tiempo_minimo_minutos', COALESCE(ROUND(EXTRACT(EPOCH FROM MIN(tiempo_respuesta)) / 60, 2), 0),
            'tiempo_maximo_minutos', COALESCE(ROUND(EXTRACT(EPOCH FROM MAX(tiempo_respuesta)) / 60, 2), 0),
            'total_alertas', COUNT(*)
        ) INTO resultado
        FROM public.historial_alertas
        WHERE area_id = pi_area_id
          AND fecha_alerta::date BETWEEN pi_fecha_inicio::date AND pi_fecha_fin::date;

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
              AND fecha_alerta::date BETWEEN pi_fecha_inicio::date AND pi_fecha_fin::date
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
    v_area_nombre VARCHAR(255);
BEGIN
    BEGIN
        -- Obtener nombre del area para filtrar por codhabcama
        SELECT nombre INTO v_area_nombre
        FROM public.areas
        WHERE id = pi_area_id;

        -- Resumen por accion (comparando solo fecha)
        SELECT COALESCE(jsonb_agg(row_data), '[]'::jsonb) INTO por_accion
        FROM (
            SELECT jsonb_build_object(
                'accion', accion,
                'total', COUNT(*)
            ) AS row_data
            FROM public.historial_notas
            WHERE codhabcama = v_area_nombre
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
            WHERE hn.codhabcama = v_area_nombre
              AND hn.fecha_registro::date BETWEEN pi_fecha_inicio::date AND pi_fecha_fin::date
            GROUP BY hn.usuario_id, u.nombre
            ORDER BY COUNT(*) DESC
        ) sub;

        -- Total general
        resultado := jsonb_build_object(
            'total', (
                SELECT COUNT(*)
                FROM public.historial_notas
                WHERE codhabcama = v_area_nombre
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
-- 3. FIX: sp_analytics_ocupacion
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
    v_area_nombre VARCHAR(255);
    v_total_ingresos INT := 0;
    v_total_egresos INT := 0;
    v_ocupacion_actual INT := 0;
    v_total_camas INT := 0;
BEGIN
    BEGIN
        -- Obtener nombre del area
        SELECT nombre INTO v_area_nombre
        FROM public.areas
        WHERE id = pi_area_id;

        -- Si no se encuentra el area, retornar valores por defecto
        IF v_area_nombre IS NULL THEN
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
        WHERE codhabcama = v_area_nombre
          AND fecha_evento::date BETWEEN pi_fecha_inicio::date AND pi_fecha_fin::date;

        -- Contar ocupacion actual (camas con paciente)
        -- Nota: columnas en minusculas (codhabcama, apenompac)
        SELECT COALESCE(COUNT(*), 0) INTO v_ocupacion_actual
        FROM public.camas_essi
        WHERE codhabcama = v_area_nombre
          AND estado = TRUE
          AND COALESCE(apenompac, '') != '';

        -- Contar total de camas activas
        SELECT COALESCE(COUNT(*), 0) INTO v_total_camas
        FROM public.camas_essi
        WHERE codhabcama = v_area_nombre
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
            WHERE codhabcama = v_area_nombre
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
-- 4. FIX: sp_analytics_frecuencia_alertas
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
        -- Total general (comparando solo fecha)
        SELECT jsonb_build_object(
            'total_alertas', COUNT(*),
            'alertas_tipo_1', COUNT(*) FILTER (WHERE tipo_alerta = 1),
            'alertas_tipo_2', COUNT(*) FILTER (WHERE tipo_alerta = 2)
        ) INTO resultado
        FROM public.historial_alertas
        WHERE area_id = pi_area_id
          AND fecha_alerta::date BETWEEN pi_fecha_inicio::date AND pi_fecha_fin::date;

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
              AND fecha_alerta::date BETWEEN pi_fecha_inicio::date AND pi_fecha_fin::date
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
              AND fecha_alerta::date BETWEEN pi_fecha_inicio::date AND pi_fecha_fin::date
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
              AND fecha_alerta::date BETWEEN pi_fecha_inicio::date AND pi_fecha_fin::date
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

-- =====================================================
-- Verificacion
-- =====================================================
DO $$
DECLARE
    v_count_alertas INT;
    v_count_notas INT;
    v_count_ocupacion INT;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'FIX APLICADO: Comparacion de fechas';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Ahora los SPs comparan fecha::date';
    RAISE NOTICE 'en lugar de TIMESTAMP completo';
    RAISE NOTICE '';

    -- Verificar tablas creadas
    SELECT COUNT(*) INTO v_count_alertas FROM public.historial_alertas;
    SELECT COUNT(*) INTO v_count_notas FROM public.historial_notas;
    SELECT COUNT(*) INTO v_count_ocupacion FROM public.historial_ocupacion;

    RAISE NOTICE 'Tablas de historial:';
    RAISE NOTICE '  - historial_alertas: % registros', v_count_alertas;
    RAISE NOTICE '  - historial_notas: % registros', v_count_notas;
    RAISE NOTICE '  - historial_ocupacion: % registros', v_count_ocupacion;
    RAISE NOTICE '';
    RAISE NOTICE 'SPs actualizados correctamente';
    RAISE NOTICE '========================================';
END $$;

-- Test del SP (solo si hay datos)
SELECT * FROM public.sp_analytics_tiempos_respuesta(1, '2025-01-01', '2027-01-01') AS result;
