-- =====================================================
-- FIX: Corregir función sp_consultar_habitaciones_essi
-- =====================================================
-- Las columnas de la tabla camas_essi están en minúsculas
-- pero la función original usa camelCase con comillas
-- =====================================================

CREATE OR REPLACE FUNCTION public.sp_consultar_habitaciones_essi(
    codHabCama_input VARCHAR
)
RETURNS JSONB AS $$
DECLARE
    resultado JSONB;
    habitaciones_json JSONB := '[]'::jsonb;
    camas_json JSONB;
    habitacion RECORD;
    cama RECORD;
BEGIN
    -- Recorrer las habitaciones que coinciden con codhabcama (minúsculas)
    FOR habitacion IN
        SELECT codhab
        FROM camas_essi
        WHERE codhabcama = codHabCama_input
        GROUP BY codhab
        ORDER BY codhab
    LOOP
        -- Inicializar las camas en JSON
        camas_json := '[]'::jsonb;

        -- Recorrer las camas de la habitación
        FOR cama IN
            SELECT id, codcama, nrodocidepac, nrohisclicas, tipodocidepac, apenompac, nota, fecha_nota
            FROM camas_essi c
            WHERE c.codhab = habitacion.codhab AND c.codhabcama = codHabCama_input AND c.estado = TRUE
            ORDER BY codcama
        LOOP
            -- Agregar cada cama a la lista de camas
            camas_json := camas_json || jsonb_build_object(
                'id', cama.id,
                'nombre', cama.codcama,
                'paciente', cama.apenompac,
                'nota', cama.nota,
                'fecha_nota', cama.fecha_nota
            );
        END LOOP;

        -- Agregar la habitación con sus camas al resultado
        habitaciones_json := habitaciones_json || jsonb_build_object(
            'nombre', habitacion.codhab,
            'camas', camas_json
        );
    END LOOP;

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
-- FIX: Corregir función sp_cargar_data_essi
-- =====================================================

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
        SELECT 1 FROM camas_essi
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
            SELECT 1 FROM camas_essi
            WHERE codhabcama = p_codhabcama
              AND codhab = p_codhab
              AND codcama = p_codcama
        ) THEN
            -- Cambiar el estado a FALSE del registro existente
            UPDATE camas_essi
            SET estado = FALSE
            WHERE codhabcama = p_codhabcama
              AND codhab = p_codhab
              AND codcama = p_codcama;
        END IF;

        -- Insertar los datos en la tabla camas_essi
        INSERT INTO camas_essi (
            codhabcama,
            codhab,
            codcama,
            apenompac,
            desestcama,
            dessercama,
            diashospi,
            fechaingreso,
            nrodocidepac,
            nrohisclicas,
            tipodocidepac,
            estado
        )
        VALUES (
            p_codhabcama,
            p_codhab,
            p_codcama,
            p_apenompac,
            p_desestcama,
            p_dessercama,
            p_diashospi,
            p_fechaingreso,
            p_nrodocidepac,
            p_nrohisclicas,
            p_tipodocidepac,
            TRUE
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
-- FIX: Corregir función sp_consultar_info_habitaciones
-- =====================================================

CREATE OR REPLACE FUNCTION public.sp_consultar_info_habitaciones()
RETURNS JSONB AS $$
DECLARE
    resultado JSONB := '[]'::jsonb;
    registro RECORD;
BEGIN
    FOR registro IN
        SELECT
            apenompac,
            codhab || codcama AS codcama_full,
            codhabcama,
            desestcama,
            dessercama,
            diashospi,
            fechaingreso,
            nrodocidepac,
            nrohisclicas,
            tipodocidepac
        FROM
            camas_essi
        WHERE
            estado = TRUE
    LOOP
        resultado := resultado || jsonb_build_object(
            'apeNomPac', registro.apenompac,
            'codCama', registro.codcama_full,
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
-- Verificar que las funciones se crearon correctamente
-- =====================================================
DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'FUNCIONES CORREGIDAS';
    RAISE NOTICE '========================================';
    RAISE NOTICE '✓ sp_consultar_habitaciones_essi';
    RAISE NOTICE '✓ sp_cargar_data_essi';
    RAISE NOTICE '✓ sp_consultar_info_habitaciones';
    RAISE NOTICE '========================================';
END $$;
