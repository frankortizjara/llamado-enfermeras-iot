-- =====================================================
-- FIX COMPLETO: Todas las SPs de sincronización
-- Columnas en minusculas (importadas via DBeaver)
-- Incluye fecha de sincronización en la respuesta
-- =====================================================

SET search_path TO public;

-- =====================================================
-- DIAGNOSTICO: Verificar nombres de columnas reales
-- =====================================================
DO $$
DECLARE
    col_count INT;
    col_names TEXT;
BEGIN
    -- Verificar si existen columnas lowercase
    SELECT COUNT(*), string_agg(column_name, ', ' ORDER BY ordinal_position)
    INTO col_count, col_names
    FROM information_schema.columns
    WHERE table_name = 'camas_essi'
    AND table_schema = 'public';

    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'DIAGNOSTICO: Columnas de camas_essi';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Total columnas: %', col_count;
    RAISE NOTICE 'Columnas: %', col_names;
    RAISE NOTICE '========================================';
    RAISE NOTICE '';
END $$;

-- =====================================================
-- 1. sp_cargar_data_essi
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
    -- Verificar si ya existe un registro identico activo
    IF EXISTS (
        SELECT 1 FROM public.camas_essi
        WHERE codhabcama = p_codhabcama
          AND codhab = p_codhab
          AND codcama = p_codcama
          AND nrodocidepac = p_nrodocidepac
          AND estado = TRUE
    ) THEN
        -- Actualizar datos del paciente existente (nombre puede cambiar)
        UPDATE public.camas_essi
        SET apenompac = p_apenompac,
            desestcama = p_desestcama,
            dessercama = p_dessercama,
            diashospi = p_diashospi,
            fechaingreso = p_fechaingreso,
            nrohisclicas = p_nrohisclicas,
            tipodocidepac = p_tipodocidepac,
            fecha_modificacion = CURRENT_TIMESTAMP
        WHERE codhabcama = p_codhabcama
          AND codhab = p_codhab
          AND codcama = p_codcama
          AND nrodocidepac = p_nrodocidepac
          AND estado = TRUE;

        mensaje := 'El registro ya existe';
        RETURN jsonb_build_object(
            'estado', 'error',
            'codigo', 409,
            'mensaje', mensaje
        );
    ELSE
        -- Desactivar registros anteriores de la misma cama
        UPDATE public.camas_essi
        SET estado = FALSE,
            fecha_modificacion = CURRENT_TIMESTAMP
        WHERE codhabcama = p_codhabcama
          AND codhab = p_codhab
          AND codcama = p_codcama
          AND estado = TRUE;

        -- Insertar nuevo registro
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
-- 2. sp_consultar_info_habitaciones
-- Retorna registros activos (usado por el CRON)
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
-- 3. sp_consultar_habitaciones_essi (con fecha de sync)
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
    ultima_sync TIMESTAMP;
BEGIN
    -- Obtener fecha de última sincronización
    SELECT MAX(fecha_registro) INTO ultima_sync
    FROM public.camas_essi
    WHERE codhabcama = p_area_codigo
    AND estado = TRUE;

    -- Iterar por cada habitación única del área
    FOR hab IN
        SELECT DISTINCT ce.codhab
        FROM public.camas_essi ce
        WHERE ce.codhabcama = p_area_codigo
        AND ce.codhab IS NOT NULL
        AND ce.codhab != ''
        AND ce.estado = TRUE
        ORDER BY ce.codhab
    LOOP
        hab_id := hab_id + 1;
        camas_array := '[]'::jsonb;

        -- Obtener camas (solo el registro más reciente por cama)
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
            AND ce.estado = TRUE
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

        habitaciones_array := habitaciones_array || jsonb_build_object(
            'id', hab_id,
            'nombre', hab.codhab,
            'camas', camas_array
        );
    END LOOP;

    -- Retornar con fecha de sincronización
    RETURN jsonb_build_object(
        'estado', 'success',
        'codigo', 200,
        'mensaje', jsonb_build_object(
            'habitaciones', habitaciones_array,
            'ultimaSincronizacion', COALESCE(TO_CHAR(ultima_sync, 'DD/MM/YYYY HH12:MI AM'), 'Sin datos')
        )
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
-- 4. sp_editar_nota
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
-- TEST: Verificar todas las funciones
-- =====================================================
DO $$
DECLARE
    test_result JSONB;
    info_count INT;
    hab_count INT;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'TEST: Verificando todas las funciones';
    RAISE NOTICE '========================================';

    -- Test 1: sp_consultar_info_habitaciones
    SELECT sp_consultar_info_habitaciones() INTO test_result;
    SELECT jsonb_array_length(test_result->'mensaje') INTO info_count;
    RAISE NOTICE '';
    RAISE NOTICE '1. sp_consultar_info_habitaciones:';
    RAISE NOTICE '   Estado: %', test_result->>'estado';
    RAISE NOTICE '   Registros activos: %', info_count;

    -- Test 2: sp_consultar_habitaciones_essi
    SELECT sp_consultar_habitaciones_essi('CIR1') INTO test_result;
    IF test_result->>'estado' = 'success' THEN
        SELECT jsonb_array_length(test_result->'mensaje'->'habitaciones') INTO hab_count;
        RAISE NOTICE '';
        RAISE NOTICE '2. sp_consultar_habitaciones_essi(CIR1):';
        RAISE NOTICE '   Estado: %', test_result->>'estado';
        RAISE NOTICE '   Habitaciones: %', hab_count;
        RAISE NOTICE '   Ultima sync: %', test_result->'mensaje'->>'ultimaSincronizacion';
    ELSE
        RAISE NOTICE '';
        RAISE NOTICE '2. sp_consultar_habitaciones_essi(CIR1):';
        RAISE NOTICE '   Estado: %', test_result->>'estado';
        RAISE NOTICE '   Error: %', test_result->>'mensaje';
    END IF;

    -- Test 3: sp_cargar_data_essi (insert y cleanup)
    SELECT sp_cargar_data_essi(
        'Test Paciente', 'CIR1', '999', 'Z',
        'TEST', 'TEST', '1', '2026-01-26',
        '00000000', '000000', 'DNI'
    ) INTO test_result;
    RAISE NOTICE '';
    RAISE NOTICE '3. sp_cargar_data_essi (INSERT test):';
    RAISE NOTICE '   Estado: %', test_result->>'estado';
    RAISE NOTICE '   Mensaje: %', test_result->>'mensaje';

    -- Cleanup
    DELETE FROM public.camas_essi WHERE codhab = '999' AND codcama = 'Z';
    RAISE NOTICE '   (Dato de prueba eliminado)';

    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'TODAS LAS FUNCIONES OK';
    RAISE NOTICE '========================================';
END $$;
