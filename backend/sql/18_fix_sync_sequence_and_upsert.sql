-- =====================================================
-- FIX: Secuencia desincronizada + SP de carga con UPSERT
-- =====================================================
-- Problema: La secuencia camas_essi_id_seq está detrás
-- del MAX(id) de la tabla, causando errores de
-- "llave duplicada viola restricción de unicidad camas_essi_pkey"
-- al intentar INSERT con un id que ya existe.
--
-- Solución:
-- 1. Resetear la secuencia al valor correcto
-- 2. Reescribir sp_cargar_data_essi con lógica UPSERT robusta
-- 3. Agregar índice único parcial para el patrón de upsert
-- =====================================================

SET search_path TO public;

-- =====================================================
-- PASO 1: Resetear la secuencia camas_essi_id_seq
-- =====================================================
DO $$
DECLARE
    max_id INT;
    current_seq INT;
BEGIN
    SELECT COALESCE(MAX(id), 0) INTO max_id FROM public.camas_essi;
    SELECT last_value INTO current_seq FROM camas_essi_id_seq;

    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'DIAGNOSTICO DE SECUENCIA';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'MAX(id) en camas_essi: %', max_id;
    RAISE NOTICE 'Valor actual de secuencia: %', current_seq;

    IF current_seq < max_id THEN
        PERFORM setval('camas_essi_id_seq', max_id);
        RAISE NOTICE 'CORREGIDO: Secuencia actualizada a %', max_id;
    ELSE
        RAISE NOTICE 'OK: Secuencia ya está sincronizada';
    END IF;

    RAISE NOTICE '========================================';
    RAISE NOTICE '';
END $$;

-- =====================================================
-- PASO 2: Crear índice único parcial en registros activos
-- Esto permite usar ON CONFLICT para upsert eficiente
-- =====================================================
DROP INDEX IF EXISTS idx_camas_essi_cama_activa;
CREATE UNIQUE INDEX idx_camas_essi_cama_activa
ON public.camas_essi (codhabcama, codhab, codcama)
WHERE estado = TRUE;

-- =====================================================
-- PASO 3: Reescribir sp_cargar_data_essi
-- Lógica UPSERT robusta que:
-- - Si existe registro activo para la misma cama con el mismo
--   paciente: actualiza sus datos
-- - Si existe registro activo para la misma cama con paciente
--   diferente: desactiva el viejo e inserta el nuevo
-- - Si no existe registro activo: inserta nuevo
-- - Maneja errores de secuencia automáticamente
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
    v_existing_id INT;
    v_existing_paciente VARCHAR;
BEGIN
    -- Buscar si existe un registro activo para esta cama
    SELECT id, nrodocidepac
    INTO v_existing_id, v_existing_paciente
    FROM public.camas_essi
    WHERE codhabcama = p_codhabcama
      AND codhab = p_codhab
      AND codcama = p_codcama
      AND estado = TRUE
    LIMIT 1;

    IF v_existing_id IS NOT NULL THEN
        -- Existe un registro activo para esta cama
        IF v_existing_paciente = p_nrodocidepac THEN
            -- Mismo paciente: actualizar datos existentes
            UPDATE public.camas_essi
            SET apenompac = p_apenompac,
                desestcama = p_desestcama,
                dessercama = p_dessercama,
                diashospi = p_diashospi,
                fechaingreso = p_fechaingreso,
                nrohisclicas = p_nrohisclicas,
                tipodocidepac = p_tipodocidepac,
                fecha_modificacion = CURRENT_TIMESTAMP
            WHERE id = v_existing_id;

            RETURN jsonb_build_object(
                'estado', 'success',
                'codigo', 200,
                'mensaje', 'Registro actualizado'
            );
        ELSE
            -- Paciente diferente: desactivar el viejo e insertar nuevo
            UPDATE public.camas_essi
            SET estado = FALSE,
                fecha_modificacion = CURRENT_TIMESTAMP
            WHERE id = v_existing_id;

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

            RETURN jsonb_build_object(
                'estado', 'success',
                'codigo', 200,
                'mensaje', 'Paciente cambiado en cama'
            );
        END IF;
    ELSE
        -- No existe registro activo: insertar nuevo
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

        RETURN jsonb_build_object(
            'estado', 'success',
            'codigo', 200,
            'mensaje', 'Registro insertado exitosamente'
        );
    END IF;

EXCEPTION
    WHEN unique_violation THEN
        -- Si hay violación de unicidad (secuencia desincronizada),
        -- corregir secuencia y reintentar como UPDATE
        PERFORM setval('camas_essi_id_seq', (SELECT MAX(id) FROM camas_essi));

        -- Intentar actualizar el registro existente en su lugar
        UPDATE public.camas_essi
        SET apenompac = p_apenompac,
            desestcama = p_desestcama,
            dessercama = p_dessercama,
            diashospi = p_diashospi,
            fechaingreso = p_fechaingreso,
            nrodocidepac = p_nrodocidepac,
            nrohisclicas = p_nrohisclicas,
            tipodocidepac = p_tipodocidepac,
            estado = TRUE,
            fecha_modificacion = CURRENT_TIMESTAMP
        WHERE codhabcama = p_codhabcama
          AND codhab = p_codhab
          AND codcama = p_codcama
          AND estado = TRUE;

        IF FOUND THEN
            RETURN jsonb_build_object(
                'estado', 'success',
                'codigo', 200,
                'mensaje', 'Registro actualizado (secuencia corregida)'
            );
        ELSE
            RETURN jsonb_build_object(
                'estado', 'error',
                'codigo', 500,
                'mensaje', 'Error de secuencia: no se pudo recuperar'
            );
        END IF;
    WHEN OTHERS THEN
        RETURN jsonb_build_object(
            'estado', 'error',
            'codigo', 500,
            'mensaje', SQLERRM
        );
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- PASO 4: Verificar las correcciones
-- =====================================================
DO $$
DECLARE
    test_result JSONB;
    seq_val INT;
    max_id INT;
BEGIN
    -- Verificar secuencia
    SELECT COALESCE(MAX(id), 0) INTO max_id FROM public.camas_essi;
    SELECT last_value INTO seq_val FROM camas_essi_id_seq;

    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'VERIFICACION POST-FIX';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'MAX(id): %  |  Secuencia: %', max_id, seq_val;

    -- Test: insertar dato de prueba
    SELECT sp_cargar_data_essi(
        'Test Fix Paciente', 'TEST', '999', 'Z',
        'TEST', 'TEST', '1', '2026-01-27',
        '00000000', '000000', 'DNI'
    ) INTO test_result;
    RAISE NOTICE 'INSERT test: % - %', test_result->>'estado', test_result->>'mensaje';

    -- Test: insertar mismo paciente (debe actualizar)
    SELECT sp_cargar_data_essi(
        'Test Fix Paciente Actualizado', 'TEST', '999', 'Z',
        'TEST', 'TEST', '2', '2026-01-27',
        '00000000', '000000', 'DNI'
    ) INTO test_result;
    RAISE NOTICE 'UPDATE test: % - %', test_result->>'estado', test_result->>'mensaje';

    -- Test: insertar paciente diferente en misma cama (debe cambiar)
    SELECT sp_cargar_data_essi(
        'Otro Paciente', 'TEST', '999', 'Z',
        'TEST', 'TEST', '1', '2026-01-27',
        '99999999', '999999', 'DNI'
    ) INTO test_result;
    RAISE NOTICE 'CAMBIO test: % - %', test_result->>'estado', test_result->>'mensaje';

    -- Limpiar datos de prueba
    DELETE FROM public.camas_essi WHERE codhabcama = 'TEST' AND codhab = '999';
    RAISE NOTICE 'Datos de prueba eliminados';

    RAISE NOTICE '';
    RAISE NOTICE 'FIX APLICADO CORRECTAMENTE';
    RAISE NOTICE '========================================';
END $$;
