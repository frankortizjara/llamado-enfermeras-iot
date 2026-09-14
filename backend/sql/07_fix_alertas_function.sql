-- =====================================================
-- FIX: sp_consultar_alertas
-- Retorna el nombre real de la habitación (101, 102, 103)
-- en lugar del habitacion_id (1, 2, 3)
-- =====================================================

DROP FUNCTION IF EXISTS public.sp_consultar_alertas(INT);

CREATE OR REPLACE FUNCTION public.sp_consultar_alertas(pi_area_id INT)
RETURNS JSONB AS $$
DECLARE
    habitaciones_json JSONB := '[]'::jsonb;
    camas_json JSONB;
    habitacion RECORD;
    cama RECORD;
    tipo_alerta_habitacion INT := 0;
    nombre_habitacion INT;
BEGIN
    -- Iterar por cada habitación con alertas activas
    FOR habitacion IN
        SELECT DISTINCT a.habitacion_id
        FROM alertas a
        WHERE a.area_id = pi_area_id
        AND a.estado_alerta = TRUE
        ORDER BY a.habitacion_id
    LOOP
        camas_json := '[]'::jsonb;
        tipo_alerta_habitacion := 1;

        -- Obtener el nombre real de la habitación
        SELECT h.nombre INTO nombre_habitacion
        FROM habitaciones h
        WHERE h.id = habitacion.habitacion_id;

        -- Si no se encuentra, usar el habitacion_id como fallback
        IF nombre_habitacion IS NULL THEN
            nombre_habitacion := habitacion.habitacion_id;
        END IF;

        -- Iterar por cada cama con alerta en esta habitación
        FOR cama IN
            SELECT a.id, a.codigo_cama, a.tipo_alerta
            FROM alertas a
            WHERE a.habitacion_id = habitacion.habitacion_id
            AND a.estado_alerta = TRUE
        LOOP
            -- Si alguna cama tiene tipo_alerta = 2, toda la habitación es emergencia
            IF cama.tipo_alerta = 2 THEN
                tipo_alerta_habitacion := 2;
            END IF;

            camas_json := camas_json || jsonb_build_object(
                'id', cama.id,
                'nombre', cama.codigo_cama
            );
        END LOOP;

        -- Agregar la habitación al JSON de respuesta
        habitaciones_json := habitaciones_json || jsonb_build_object(
            'nombre', nombre_habitacion,  -- Ahora retorna el nombre real (101, 102, etc.)
            'estado', tipo_alerta_habitacion,
            'camas', camas_json
        );
    END LOOP;

    RETURN jsonb_build_object('estado', 'success', 'codigo', 200, 'mensaje', habitaciones_json);
EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object('estado', 'error', 'codigo', 500, 'mensaje', SQLERRM);
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- VERIFICAR
-- =====================================================
DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'FUNCIÓN sp_consultar_alertas ACTUALIZADA';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Ahora retorna el nombre real de la habitación';
    RAISE NOTICE '(101, 102, 103) en lugar de habitacion_id (1, 2, 3)';
    RAISE NOTICE '';
    RAISE NOTICE 'Recarga la página del frontend para ver los cambios';
    RAISE NOTICE '========================================';
END $$;
