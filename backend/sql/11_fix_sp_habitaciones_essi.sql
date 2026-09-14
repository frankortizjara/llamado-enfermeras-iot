-- =====================================================
-- FIX: sp_consultar_habitaciones_essi
-- Retorna habitaciones agrupadas con camas para un área
-- =====================================================

SET search_path TO public;

DROP FUNCTION IF EXISTS public.sp_consultar_habitaciones_essi(VARCHAR);

CREATE OR REPLACE FUNCTION public.sp_consultar_habitaciones_essi(p_area_codigo VARCHAR)
RETURNS JSONB AS $$
DECLARE
    resultado JSONB;
    habitaciones_array JSONB := '[]'::jsonb;
    hab RECORD;
    camas_array JSONB;
    cama RECORD;
    hab_id INT := 0;
    cama_id INT := 0;
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
        cama_id := 0;

        -- Obtener todas las camas de esta habitación
        FOR cama IN
            SELECT
                ce.id,
                COALESCE(NULLIF(ce.codcama, ''), '-') as nombre_cama,
                COALESCE(ce.apenompac, '') as paciente,
                ce.nota,
                ce.fecha_nota
            FROM public.camas_essi ce
            WHERE ce.codhabcama = p_area_codigo
            AND ce.codhab = hab.codhab
            ORDER BY ce.codcama
        LOOP
            cama_id := cama_id + 1;
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

    -- Construir respuesta
    resultado := jsonb_build_object(
        'error', false,
        'status', 200,
        'body', habitaciones_array
    );

    RETURN resultado;

EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object(
            'error', true,
            'status', 500,
            'body', SQLERRM
        );
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- TEST: Probar la función
-- =====================================================
DO $$
DECLARE
    test_result JSONB;
BEGIN
    SELECT sp_consultar_habitaciones_essi('CIR1') INTO test_result;
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'TEST sp_consultar_habitaciones_essi';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Resultado para CIR1: %', test_result;
    RAISE NOTICE '';
END $$;

-- =====================================================
-- VERIFICAR asignación del usuario admin
-- =====================================================
DO $$
DECLARE
    admin_area VARCHAR;
BEGIN
    SELECT ar.nombre INTO admin_area
    FROM usuarios u
    JOIN asignaciones_usuarios au ON u.id = au.usuario_id
    JOIN areas ar ON au.area_id = ar.id
    WHERE u.usuario = 'admin'
    LIMIT 1;

    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'VERIFICACION USUARIO ADMIN';
    RAISE NOTICE '========================================';

    IF admin_area IS NULL THEN
        RAISE NOTICE 'ADVERTENCIA: El usuario admin NO tiene area asignada!';
        RAISE NOTICE 'Ejecuta el siguiente SQL para asignar:';
        RAISE NOTICE '';
        RAISE NOTICE 'INSERT INTO asignaciones_usuarios (usuario_id, area_id, rol, estado)';
        RAISE NOTICE 'SELECT u.id, 1, ''admin'', true';
        RAISE NOTICE 'FROM usuarios u WHERE u.usuario = ''admin'';';
    ELSE
        RAISE NOTICE 'Usuario admin tiene area: %', admin_area;
    END IF;
    RAISE NOTICE '========================================';
END $$;
