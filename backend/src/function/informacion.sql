-- ============================================
-- Stored Procedures para Información
-- Sistema de Llamado de Enfermeras
-- CORREGIDO: 'éxito' -> 'success' para consistencia
-- ============================================

CREATE OR REPLACE FUNCTION public.sp_consultar_habitaciones(
    pi_id INT
)
RETURNS JSONB AS $$
DECLARE
    resultado JSONB;
    usuario_existe BOOLEAN;
    habitaciones_json JSONB;
    camas_json JSONB;
    habitacion RECORD;
    cama RECORD;
BEGIN
    -- Verificar si el usuario existe
    SELECT EXISTS(
        SELECT 1
        FROM public.usuarios
        WHERE id = pi_id
    ) INTO usuario_existe;

    IF usuario_existe THEN
        -- Inicializar la variable para el resultado
        habitaciones_json := '[]'::jsonb;

        -- Recorrer las habitaciones del área asignada al usuario
        FOR habitacion IN
            SELECT h.id, h.nombre
            FROM habitaciones h
            JOIN asignaciones_usuarios au ON au.area_id = h.area_id
            WHERE au.usuario_id = pi_id AND h.estado = TRUE
        LOOP
            -- Inicializar las camas en JSON
            camas_json := '[]'::jsonb;

            -- Recorrer las camas de la habitación
            FOR cama IN
                SELECT c.id, c.nombre, c.paciente
                FROM camas c
                WHERE c.habitacion_id = habitacion.id AND c.estado = TRUE
            LOOP
                -- Agregar cada cama a la lista de camas
                camas_json := camas_json || jsonb_build_object(
                    'id', cama.id,
                    'nombre', cama.nombre,
                    'paciente', cama.paciente
                );
            END LOOP;

            -- Agregar la habitación con sus camas al resultado
            habitaciones_json := habitaciones_json || jsonb_build_object(
                'id', habitacion.id,
                'nombre', habitacion.nombre,
                'camas', camas_json
            );
        END LOOP;

        -- CORREGIDO: 'success' en lugar de 'éxito'
        RETURN jsonb_build_object(
            'estado', 'success',
            'codigo', 200,
            'mensaje', habitaciones_json
        );
    ELSE
        RETURN jsonb_build_object(
            'estado', 'error',
            'codigo', 404,
            'mensaje', 'Usuario no encontrado'
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

-- ============================================
-- SP para consultar habitaciones EsSi
-- ============================================

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
    -- Recorrer las habitaciones que coinciden con codHabCama
    FOR habitacion IN
        SELECT "codHab"
        FROM camas_essi
        WHERE "codHabCama" = codHabCama_input
        GROUP BY "codHab"
        ORDER BY "codHab"
    LOOP
        -- Inicializar las camas en JSON
        camas_json := '[]'::jsonb;

        -- Recorrer las camas de la habitación
        FOR cama IN
            SELECT id, "codCama", "nroDocIdePac", "nroHisCliCas", "tipoDocIdePac", "apeNomPac"
            FROM camas_essi c
            WHERE c."codHab" = habitacion."codHab" AND c."codHabCama" = codHabCama_input AND c.estado = TRUE
            ORDER BY "codCama"
        LOOP
            -- Agregar cada cama a la lista de camas
            camas_json := camas_json || jsonb_build_object(
                'id', cama.id,
                'nombre', cama."codCama",
                'paciente', cama."apeNomPac"
            );
        END LOOP;

        -- Agregar la habitación con sus camas al resultado
        habitaciones_json := habitaciones_json || jsonb_build_object(
            'nombre', habitacion."codHab",
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

-- ============================================
-- SP para cargar data EsSi
-- ============================================

CREATE OR REPLACE FUNCTION public.sp_cargar_data_essi(
    apeNomPac VARCHAR,
    codHabCama VARCHAR,
    codHab VARCHAR,
    codCama VARCHAR,
    desEstCama VARCHAR,
    desSerCama VARCHAR,
    diashospi VARCHAR,
    fechaIngreso VARCHAR,
    nroDocIdePac VARCHAR,
    nroHisCliCas VARCHAR,
    tipoDocIdePac VARCHAR
)
RETURNS JSONB AS $$
DECLARE
    mensaje VARCHAR;
BEGIN
    -- Verificar si ya existe un registro con los mismos valores clave
    IF EXISTS (
        SELECT 1 FROM camas_essi
        WHERE "codHabCama" = codHabCama
          AND "codHab" = codHab
          AND "codCama" = codCama
          AND "nroDocIdePac" = nroDocIdePac
    ) THEN
        mensaje := 'El registro ya existe';
        RETURN jsonb_build_object(
            'estado', 'error',
            'codigo', 409,
            'mensaje', mensaje
        );
    ELSE
        -- Verificar si existe otro registro con el mismo codHabCama, codHab y codCama
        IF EXISTS (
            SELECT 1 FROM camas_essi
            WHERE "codHabCama" = codHabCama
              AND "codHab" = codHab
              AND "codCama" = codCama
        ) THEN
            -- Cambiar el estado a FALSE del registro existente
            UPDATE camas_essi
            SET estado = FALSE
            WHERE "codHabCama" = codHabCama
              AND "codHab" = codHab
              AND "codCama" = codCama;
        END IF;

        -- Insertar los datos en la tabla camas_essi
        INSERT INTO camas_essi (
            "codHabCama",
            "codHab",
            "codCama",
            "apeNomPac",
            "desEstCama",
            "desSerCama",
            "diashospi",
            "fechaIngreso",
            "nroDocIdePac",
            "nroHisCliCas",
            "tipoDocIdePac",
            estado
        )
        VALUES (
            codHabCama,
            codHab,
            codCama,
            apeNomPac,
            desEstCama,
            desSerCama,
            diashospi,
            fechaIngreso,
            nroDocIdePac,
            nroHisCliCas,
            tipoDocIdePac,
            TRUE
        );

        -- CORREGIDO: 'success' en lugar de 'éxito'
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

-- ============================================
-- SP para consultar alertas
-- CORREGIDO: typo 'tipo_alerta_habitacioN' -> 'tipo_alerta_habitacion'
-- ============================================

CREATE OR REPLACE FUNCTION public.sp_consultar_alertas(
    pi_area_id INT
)
RETURNS JSONB AS $$
DECLARE
    resultado JSONB;
    habitaciones_json JSONB := '[]'::jsonb;
    camas_json JSONB;
    habitacion RECORD;
    cama RECORD;
    tipo_alerta_habitacion INT := 0;
BEGIN
    -- Recorrer las habitaciones con alertas activas
    FOR habitacion IN
        SELECT DISTINCT a.habitacion_id
        FROM alertas a
        WHERE a.area_id = pi_area_id
            AND a.estado_alerta = TRUE
        ORDER BY a.habitacion_id
    LOOP
        -- Inicializar las camas en JSON
        camas_json := '[]'::jsonb;
        tipo_alerta_habitacion := 1;

        -- Recorrer las camas de la habitación con alertas activas
        FOR cama IN
            SELECT a.id, a.codigo_cama, a.tipo_alerta
            FROM alertas a
            WHERE a.habitacion_id = habitacion.habitacion_id
              AND a.estado_alerta = TRUE
            ORDER BY a.habitacion_id
        LOOP
            IF cama.tipo_alerta = 2 THEN
                tipo_alerta_habitacion := 2;
            END IF;

            -- Agregar cada cama con alerta activa a la lista de camas
            camas_json := camas_json || jsonb_build_object(
                'id', cama.id,
                'nombre', cama.codigo_cama
            );
        END LOOP;

        -- Agregar la habitación con sus camas al resultado
        habitaciones_json := habitaciones_json || jsonb_build_object(
            'nombre', habitacion.habitacion_id,
            'estado', tipo_alerta_habitacion,
            'camas', camas_json
        );
    END LOOP;

    -- CORREGIDO: 'success' en lugar de 'éxito'
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

-- ============================================
-- SP para consultar info habitaciones
-- ============================================

CREATE OR REPLACE FUNCTION public.sp_consultar_info_habitaciones()
RETURNS JSONB AS $$
DECLARE
    resultado JSONB := '[]'::jsonb;
    registro RECORD;
BEGIN
    -- Ejecutar la consulta y recorrer los resultados
    FOR registro IN
        SELECT
            "apeNomPac",
            "codHab" || "codCama" AS "codCama",
            "codHabCama",
            "desEstCama",
            "desSerCama",
            "diashospi",
            "fechaIngreso",
            "nroDocIdePac",
            "nroHisCliCas",
            "tipoDocIdePac"
        FROM
            camas_essi
        WHERE
            estado = TRUE
    LOOP
        -- Agregar cada registro en el orden deseado
        resultado := resultado || jsonb_build_object(
            'apeNomPac', registro."apeNomPac",
            'codCama', registro."codCama",
            'codHabCama', registro."codHabCama",
            'desEstCama', registro."desEstCama",
            'desSerCama', registro."desSerCama",
            'diashospi', registro."diashospi",
            'fechaIngreso', registro."fechaIngreso",
            'nroDocIdePac', registro."nroDocIdePac",
            'nroHisCliCas', registro."nroHisCliCas",
            'tipoDocIdePac', registro."tipoDocIdePac"
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

-- ============================================
-- SP para editar nota
-- ============================================

CREATE OR REPLACE FUNCTION public.sp_editar_nota(
    pi_id INT,
    pi_nota TEXT,
    pi_fecha_nota TEXT
)
RETURNS JSONB AS $$
DECLARE
    resultado JSONB;
BEGIN
    -- Actualizar nota existente
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
