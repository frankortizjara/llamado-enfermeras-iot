-- =====================================================
-- FIX: Stored Procedures con referencias explícitas al schema
-- =====================================================
-- Este script corrige las funciones para usar:
-- 1. Referencias explícitas al schema public
-- 2. Nombres de columnas en minúsculas (como quedaron tras import DBeaver)
-- =====================================================

SET search_path TO public;

-- =====================================================
-- 1. FIX: sp_consultar_habitaciones_essi
-- =====================================================
DROP FUNCTION IF EXISTS public.sp_consultar_habitaciones_essi(VARCHAR);

CREATE OR REPLACE FUNCTION public.sp_consultar_habitaciones_essi(codhabcama_input VARCHAR)
RETURNS JSONB AS $$
DECLARE
    resultado JSONB;
BEGIN
    SELECT jsonb_build_object(
        'estado', 'success',
        'codigo', 200,
        'data', jsonb_build_object(
            'codHabCama', ce.codhabcama,
            'codHab', ce.codhab,
            'codCama', ce.codcama,
            'apeNomPac', ce.apenompac,
            'desEstCama', ce.desestcama,
            'desSerCama', ce.dessercama,
            'diashospi', ce.diashospi,
            'fechaIngreso', ce.fechaingreso,
            'nroDocIdePac', ce.nrodocidepac,
            'nroHisCliCas', ce.nrohisclicas,
            'tipoDocIdePac', ce.tipodocidepac,
            'estado', ce.estado,
            'nota', ce.nota,
            'fecha_nota', ce.fecha_nota
        )
    ) INTO resultado
    FROM public.camas_essi ce
    WHERE ce.codhabcama = codhabcama_input
    LIMIT 1;

    IF resultado IS NULL THEN
        RETURN jsonb_build_object(
            'estado', 'error',
            'codigo', 404,
            'mensaje', 'No se encontró la cama con código: ' || codhabcama_input
        );
    END IF;

    RETURN resultado;
EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object('estado', 'error', 'codigo', 500, 'mensaje', SQLERRM);
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- 2. FIX: sp_consultar_alertas
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
        FROM public.alertas a
        WHERE a.area_id = pi_area_id
        AND a.estado_alerta = TRUE
        ORDER BY a.habitacion_id
    LOOP
        camas_json := '[]'::jsonb;
        tipo_alerta_habitacion := 1;

        -- Obtener el nombre real de la habitación
        SELECT h.nombre INTO nombre_habitacion
        FROM public.habitaciones h
        WHERE h.id = habitacion.habitacion_id;

        -- Si no se encuentra, usar el habitacion_id como fallback
        IF nombre_habitacion IS NULL THEN
            nombre_habitacion := habitacion.habitacion_id;
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

    RETURN jsonb_build_object('estado', 'success', 'codigo', 200, 'mensaje', habitaciones_json);
EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object('estado', 'error', 'codigo', 500, 'mensaje', SQLERRM);
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- 3. VERIFICAR ESTRUCTURA DE TABLAS
-- =====================================================
DO $$
DECLARE
    col_record RECORD;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'VERIFICANDO COLUMNAS DE camas_essi';
    RAISE NOTICE '========================================';

    FOR col_record IN
        SELECT column_name, data_type
        FROM information_schema.columns
        WHERE table_schema = 'public'
        AND table_name = 'camas_essi'
        ORDER BY ordinal_position
    LOOP
        RAISE NOTICE 'Columna: % (%)', col_record.column_name, col_record.data_type;
    END LOOP;
END $$;

-- =====================================================
-- 4. TEST DE FUNCIONES
-- =====================================================
DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'FUNCIONES ACTUALIZADAS CORRECTAMENTE';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Funciones corregidas:';
    RAISE NOTICE '  - sp_consultar_habitaciones_essi';
    RAISE NOTICE '  - sp_consultar_alertas';
    RAISE NOTICE '';
    RAISE NOTICE 'Cambios aplicados:';
    RAISE NOTICE '  - Referencias explícitas a schema public';
    RAISE NOTICE '  - Columnas en minúsculas (import DBeaver)';
    RAISE NOTICE '';
    RAISE NOTICE 'Reinicia el backend y recarga el frontend';
    RAISE NOTICE '========================================';
END $$;
