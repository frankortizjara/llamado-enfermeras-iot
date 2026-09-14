-- =====================================================
-- FIX: Corregir formato de respuesta de stored procedures
-- El backend espera: { estado, codigo, mensaje }
-- NO: { error, status, body }
-- =====================================================

SET search_path TO public;

-- =====================================================
-- 1. FIX: sp_consultar_habitaciones_essi
-- =====================================================
DROP FUNCTION IF EXISTS public.sp_consultar_habitaciones_essi(VARCHAR);

CREATE OR REPLACE FUNCTION public.sp_consultar_habitaciones_essi(p_area_codigo VARCHAR)
RETURNS JSONB AS $$
DECLARE
    habitaciones_array JSONB := '[]'::jsonb;
    hab RECORD;
    camas_array JSONB;
    cama RECORD;
    hab_id INT := 0;
BEGIN
    -- Iterar por cada habitación única del área
    FOR hab IN
        SELECT DISTINCT ce.codhab
        FROM public.camas_essi ce
        WHERE ce.codhabcama = p_area_codigo
        AND ce.codhab IS NOT NULL
        AND ce.codhab != ''
        ORDER BY ce.codhab
    LOOP
        hab_id := hab_id + 1;
        camas_array := '[]'::jsonb;

        -- Obtener todas las camas de esta habitación (solo el registro más reciente por cama)
        FOR cama IN
            SELECT DISTINCT ON (COALESCE(NULLIF(ce.codcama, ''), '-'))
                ce.id,
                COALESCE(NULLIF(ce.codcama, ''), '-') as nombre_cama,
                COALESCE(ce.apenompac, '') as paciente,
                COALESCE(ce.nota, '') as nota,
                COALESCE(ce.fecha_nota, '') as fecha_nota
            FROM public.camas_essi ce
            WHERE ce.codhabcama = p_area_codigo
            AND ce.codhab = hab.codhab
            ORDER BY COALESCE(NULLIF(ce.codcama, ''), '-'), ce.id DESC
        LOOP
            camas_array := camas_array || jsonb_build_object(
                'id', cama.id,
                'nombre', cama.nombre_cama,
                'paciente', cama.paciente,
                'nota', cama.nota,
                'fecha_nota', cama.fecha_nota
            );
        END LOOP;

        -- Agregar habitación al array
        habitaciones_array := habitaciones_array || jsonb_build_object(
            'id', hab_id,
            'nombre', hab.codhab,
            'camas', camas_array
        );
    END LOOP;

    -- Retornar en el formato que espera el backend
    RETURN jsonb_build_object(
        'estado', 'success',
        'codigo', 200,
        'mensaje', habitaciones_array
    );

EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object(
            'estado', 'error',
            'codigo', 500,
            'mensaje', SQLERRM
        );
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- 2. FIX: sp_consultar_alertas (verificar formato)
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
    nombre_habitacion VARCHAR;
BEGIN
    -- Iterar por cada habitación con alertas activas
    FOR habitacion IN
        SELECT DISTINCT a.habitacion_id
        FROM public.alertas a
        WHERE a.area_id = pi_area_id
        AND a.estado_alerta = TRUE
        ORDER BY a.habitacion_id
    LOOP
        camas_json := '[]'::jsonb;
        tipo_alerta_habitacion := 1;

        -- Obtener el nombre real de la habitación
        SELECT h.nombre::VARCHAR INTO nombre_habitacion
        FROM public.habitaciones h
        WHERE h.id = habitacion.habitacion_id;

        -- Si no se encuentra, usar el habitacion_id como fallback
        IF nombre_habitacion IS NULL THEN
            nombre_habitacion := habitacion.habitacion_id::VARCHAR;
        END IF;

        -- Iterar por cada cama con alerta en esta habitación
        FOR cama IN
            SELECT a.id, a.codigo_cama, a.tipo_alerta
            FROM public.alertas a
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
            'nombre', nombre_habitacion,
            'estado', tipo_alerta_habitacion,
            'camas', camas_json
        );
    END LOOP;

    -- Formato correcto para el backend
    RETURN jsonb_build_object(
        'estado', 'success',
        'codigo', 200,
        'mensaje', habitaciones_json
    );
EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object(
            'estado', 'error',
            'codigo', 500,
            'mensaje', SQLERRM
        );
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- TEST
-- =====================================================
DO $$
DECLARE
    test_result JSONB;
    hab_count INT;
BEGIN
    SELECT sp_consultar_habitaciones_essi('CIR1') INTO test_result;

    -- Contar habitaciones
    SELECT jsonb_array_length(test_result->'mensaje') INTO hab_count;

    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'TEST RESULTADO';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Estado: %', test_result->>'estado';
    RAISE NOTICE 'Codigo: %', test_result->>'codigo';
    RAISE NOTICE 'Habitaciones encontradas: %', hab_count;
    RAISE NOTICE '';

    -- Mostrar primeras 3 habitaciones
    IF hab_count > 0 THEN
        RAISE NOTICE 'Primeras habitaciones:';
        FOR i IN 0..LEAST(2, hab_count - 1) LOOP
            RAISE NOTICE '  - Habitacion %: % camas',
                test_result->'mensaje'->i->>'nombre',
                jsonb_array_length(test_result->'mensaje'->i->'camas');
        END LOOP;
    END IF;

    RAISE NOTICE '========================================';
END $$;
