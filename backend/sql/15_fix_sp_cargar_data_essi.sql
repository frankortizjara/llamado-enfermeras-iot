-- =====================================================
-- FIX: Stored Procedures con columnas en minusculas
-- Las columnas importadas via DBeaver son lowercase
-- Los SPs originales usaban camelCase con comillas
-- =====================================================

SET search_path TO public;

-- =====================================================
-- 1. FIX: sp_cargar_data_essi
-- Inserta/actualiza datos de pacientes desde API EsSi
-- =====================================================
DROP FUNCTION IF EXISTS public.sp_cargar_data_essi(VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR);

CREATE OR REPLACE FUNCTION public.sp_cargar_data_essi(
    p_apenompac VARCHAR,
    p_codhabcama VARCHAR,
    p_codhab VARCHAR,
    p_codcama VARCHAR,
    p_desestcama VARCHAR,
    p_dessercama VARCHAR,
    p_diashospi VARCHAR,
    p_fechaingreso VARCHAR,
    p_nrodocidepac VARCHAR,
    p_nrohisclicas VARCHAR,
    p_tipodocidepac VARCHAR
)
RETURNS JSONB AS $$
DECLARE
    mensaje VARCHAR;
BEGIN
    -- Verificar si ya existe un registro con los mismos valores clave
    IF EXISTS (
        SELECT 1 FROM public.camas_essi
        WHERE codhabcama = p_codhabcama
          AND codhab = p_codhab
          AND codcama = p_codcama
          AND nrodocidepac = p_nrodocidepac
    ) THEN
        mensaje := 'El registro ya existe';
        RETURN jsonb_build_object(
            'estado', 'error',
            'codigo', 409,
            'mensaje', mensaje
        );
    ELSE
        -- Verificar si existe otro registro con el mismo codhabcama, codhab y codcama
        IF EXISTS (
            SELECT 1 FROM public.camas_essi
            WHERE codhabcama = p_codhabcama
              AND codhab = p_codhab
              AND codcama = p_codcama
        ) THEN
            -- Cambiar el estado a FALSE del registro existente
            UPDATE public.camas_essi
            SET estado = FALSE,
                fecha_modificacion = CURRENT_TIMESTAMP
            WHERE codhabcama = p_codhabcama
              AND codhab = p_codhab
              AND codcama = p_codcama;
        END IF;

        -- Insertar los datos en la tabla camas_essi
        INSERT INTO public.camas_essi (
            codhabcama, codhab, codcama, apenompac,
            desestcama, dessercama, diashospi, fechaingreso,
            nrodocidepac, nrohisclicas, tipodocidepac,
            estado, fecha_registro, fecha_modificacion
        ) VALUES (
            p_codhabcama, p_codhab, p_codcama, p_apenompac,
            p_desestcama, p_dessercama, p_diashospi, p_fechaingreso,
            p_nrodocidepac, p_nrohisclicas, p_tipodocidepac,
            TRUE, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
        );

        mensaje := 'Registro insertado exitosamente';
        RETURN jsonb_build_object(
            'estado', 'success',
            'codigo', 200,
            'mensaje', mensaje
        );
    END IF;

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
-- 2. FIX: sp_consultar_info_habitaciones
-- Retorna todos los registros activos de camas_essi
-- (Usado por el CRON para comparar datos)
-- =====================================================
DROP FUNCTION IF EXISTS public.sp_consultar_info_habitaciones();

CREATE OR REPLACE FUNCTION public.sp_consultar_info_habitaciones()
RETURNS JSONB AS $$
DECLARE
    resultado JSONB := '[]'::jsonb;
    registro RECORD;
BEGIN
    FOR registro IN
        SELECT
            apenompac,
            codhab || codcama AS codcama_completo,
            codhabcama,
            desestcama,
            dessercama,
            diashospi,
            fechaingreso,
            nrodocidepac,
            nrohisclicas,
            tipodocidepac
        FROM public.camas_essi
        WHERE estado = TRUE
    LOOP
        resultado := resultado || jsonb_build_object(
            'apeNomPac', registro.apenompac,
            'codCama', registro.codcama_completo,
            'codHabCama', registro.codhabcama,
            'desEstCama', registro.desestcama,
            'desSerCama', registro.dessercama,
            'diashospi', registro.diashospi,
            'fechaIngreso', registro.fechaingreso,
            'nroDocIdePac', registro.nrodocidepac,
            'nroHisCliCas', registro.nrohisclicas,
            'tipoDocIdePac', registro.tipodocidepac
        );
    END LOOP;

    RETURN jsonb_build_object(
        'estado', 'success',
        'codigo', 200,
        'mensaje', resultado
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
-- 3. FIX: sp_editar_nota (tambien usa columnas correctas)
-- =====================================================
CREATE OR REPLACE FUNCTION public.sp_editar_nota(
    pi_id INT,
    pi_nota TEXT,
    pi_fecha_nota TEXT
)
RETURNS JSONB AS $$
DECLARE
    resultado JSONB;
BEGIN
    UPDATE public.camas_essi
    SET nota = pi_nota,
        fecha_nota = pi_fecha_nota,
        fecha_modificacion = CURRENT_TIMESTAMP
    WHERE id = pi_id;

    IF FOUND THEN
        resultado := jsonb_build_object(
            'estado', 'success',
            'codigo', 200,
            'mensaje', 'Nota actualizada'
        );
    ELSE
        resultado := jsonb_build_object(
            'estado', 'error',
            'codigo', 404,
            'mensaje', 'Nota no encontrada'
        );
    END IF;

    RETURN resultado;

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
    info_count INT;
BEGIN
    -- Test sp_consultar_info_habitaciones
    SELECT sp_consultar_info_habitaciones() INTO test_result;
    SELECT jsonb_array_length(test_result->'mensaje') INTO info_count;

    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'TEST RESULTADOS';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'sp_consultar_info_habitaciones:';
    RAISE NOTICE '  Estado: %', test_result->>'estado';
    RAISE NOTICE '  Registros activos: %', info_count;
    RAISE NOTICE '';

    -- Test sp_cargar_data_essi (insertar y verificar)
    SELECT sp_cargar_data_essi(
        'Test Paciente',  -- apenompac
        'CIR1',           -- codhabcama
        '999',            -- codhab
        'Z',              -- codcama
        'TEST',           -- desestcama
        'TEST SERVICE',   -- dessercama
        '1',              -- diashospi
        '2026-01-26',     -- fechaingreso
        '00000000',       -- nrodocidepac
        '000000',         -- nrohisclicas
        'DNI'             -- tipodocidepac
    ) INTO test_result;

    RAISE NOTICE 'sp_cargar_data_essi (INSERT test):';
    RAISE NOTICE '  Estado: %', test_result->>'estado';
    RAISE NOTICE '  Mensaje: %', test_result->>'mensaje';

    -- Limpiar dato de prueba
    DELETE FROM public.camas_essi WHERE codhab = '999' AND codcama = 'Z';
    RAISE NOTICE '  (Dato de prueba eliminado)';

    RAISE NOTICE '';
    RAISE NOTICE 'Todas las funciones corregidas OK';
    RAISE NOTICE '========================================';
END $$;
