-- =====================================================
-- MIGRACIÓN 20: Tablas de historial + SPs actualizados
-- =====================================================
-- Crea tablas de auditoría para:
--   1. historial_notas     - Cambios en notas clínicas
--   2. historial_alertas   - Alertas resueltas con tiempos
--   3. historial_ocupacion - Ingresos y egresos de pacientes
--
-- Actualiza stored procedures:
--   - sp_editar_nota       - Registra cambios en historial_notas
--   - sp_agregar_registro  - Registra resolución en historial_alertas
--   - sp_cargar_data_essi  - Registra ocupación en historial_ocupacion
-- =====================================================

SET search_path TO public;

-- =====================================================
-- PASO 1: Crear tabla historial_notas
-- =====================================================

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

CREATE INDEX IF NOT EXISTS idx_historial_notas_cama
    ON public.historial_notas(cama_essi_id);
CREATE INDEX IF NOT EXISTS idx_historial_notas_fecha
    ON public.historial_notas(fecha_registro);
CREATE INDEX IF NOT EXISTS idx_historial_notas_usuario
    ON public.historial_notas(usuario_id);

-- =====================================================
-- PASO 2: Crear tabla historial_alertas
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
CREATE INDEX IF NOT EXISTS idx_historial_alertas_habitacion
    ON public.historial_alertas(habitacion_id);

-- =====================================================
-- PASO 3: Crear tabla historial_ocupacion
-- =====================================================

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

CREATE INDEX IF NOT EXISTS idx_historial_ocupacion_cama
    ON public.historial_ocupacion(codhab, codcama);
CREATE INDEX IF NOT EXISTS idx_historial_ocupacion_fecha
    ON public.historial_ocupacion(fecha_evento);
CREATE INDEX IF NOT EXISTS idx_historial_ocupacion_paciente
    ON public.historial_ocupacion(nrodocidepac);

-- =====================================================
-- PASO 4: Actualizar sp_editar_nota
-- Agrega parámetro usuario_id y registra en historial
-- =====================================================

DROP FUNCTION IF EXISTS public.sp_editar_nota(INT, TEXT, TEXT);
DROP FUNCTION IF EXISTS public.sp_editar_nota(INT, TEXT, TEXT, INT);

CREATE OR REPLACE FUNCTION public.sp_editar_nota(
    pi_id INT,
    pi_nota TEXT,
    pi_fecha_nota TEXT,
    pi_usuario_id INT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_nota_anterior VARCHAR(50);
    v_fecha_nota_anterior VARCHAR(255);
    v_codhabcama VARCHAR(255);
    v_codhab VARCHAR(255);
    v_codcama VARCHAR(255);
    v_paciente VARCHAR(255);
    v_accion VARCHAR(20);
BEGIN
    -- Leer valores actuales de la cama
    -- IMPORTANTE: usar comillas en columnas mixedCase de camas_essi
    SELECT nota, fecha_nota, "codHabCama", "codHab", "codCama", "apeNomPac"
    INTO v_nota_anterior, v_fecha_nota_anterior, v_codhabcama, v_codhab, v_codcama, v_paciente
    FROM public.camas_essi
    WHERE id = pi_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'estado', 'error',
            'codigo', 404,
            'mensaje', 'Cama no encontrada'
        );
    END IF;

    -- Determinar tipo de acción
    IF COALESCE(v_nota_anterior, '') = '' AND COALESCE(pi_nota, '') != '' THEN
        v_accion := 'CREAR';
    ELSIF COALESCE(v_nota_anterior, '') != '' AND COALESCE(pi_nota, '') = '' THEN
        v_accion := 'ELIMINAR';
    ELSIF COALESCE(v_nota_anterior, '') != '' AND COALESCE(pi_nota, '') != '' THEN
        v_accion := 'MODIFICAR';
    ELSE
        -- Ambos vacíos, no hay cambio real en nota
        v_accion := 'MODIFICAR';
    END IF;

    -- Registrar en historial
    INSERT INTO public.historial_notas (
        cama_essi_id, codhabcama, codhab, codcama, paciente,
        nota_anterior, nota_nueva,
        fecha_nota_anterior, fecha_nota_nueva,
        accion, usuario_id
    ) VALUES (
        pi_id, v_codhabcama, v_codhab, v_codcama, v_paciente,
        COALESCE(v_nota_anterior, ''), COALESCE(pi_nota, ''),
        COALESCE(v_fecha_nota_anterior, ''), COALESCE(pi_fecha_nota, ''),
        v_accion, pi_usuario_id
    );

    -- Actualizar la nota
    UPDATE public.camas_essi
    SET nota = pi_nota,
        fecha_nota = pi_fecha_nota,
        fecha_modificacion = CURRENT_TIMESTAMP
    WHERE id = pi_id;

    RETURN jsonb_build_object(
        'estado', 'success',
        'codigo', 200,
        'mensaje', 'Nota actualizada'
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
-- PASO 5: Actualizar sp_agregar_registro
-- Registra alertas resueltas en historial_alertas
-- =====================================================

DROP FUNCTION IF EXISTS public.sp_agregar_registro(TEXT, INT, INT, TEXT, INT);

CREATE OR REPLACE FUNCTION public.sp_agregar_registro(
    pi_numero_serial TEXT,
    pi_area_id INT,
    pi_habitacion_id INT,
    pi_codigo_cama TEXT,
    pi_tipo_alerta INT
)
RETURNS JSONB AS $$
DECLARE
    resultado JSONB;
    v_dispositivo_id INT;
    v_alerta_id INT;
    alerta RECORD;
    v_alertas_resueltas INT := 0;
BEGIN
    BEGIN
        -- Buscar el dispositivo por numero_serial
        SELECT id INTO v_dispositivo_id
        FROM public.esp32_dispositivos
        WHERE numero_serial = pi_numero_serial
        LIMIT 1;

        IF v_dispositivo_id IS NOT NULL THEN
            -- Verificar el tipo de alerta
            IF pi_tipo_alerta = 1 OR pi_tipo_alerta = 2 THEN

                -- Buscar si ya existe un registro de alerta activa
                FOR alerta IN
                    SELECT id
                    FROM public.alertas
                    WHERE dispositivo_id = v_dispositivo_id
                    AND area_id = pi_area_id
                    AND habitacion_id = pi_habitacion_id
                    AND codigo_cama = pi_codigo_cama
                    AND tipo_alerta = pi_tipo_alerta
                    AND estado_alerta = TRUE
                LOOP
                    RETURN jsonb_build_object(
                        'estado', 'success',
                        'codigo', 409,
                        'mensaje', 'Registro aún sin atender'
                    );
                END LOOP;

                -- Si no se encontró ningún registro activo, insertar nuevo
                INSERT INTO public.alertas (
                    dispositivo_id, area_id, habitacion_id, codigo_cama,
                    tipo_alerta, estado_alerta, fecha_registro, fecha_modificacion
                ) VALUES (
                    v_dispositivo_id, pi_area_id, pi_habitacion_id, pi_codigo_cama,
                    pi_tipo_alerta, TRUE, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
                );

                RETURN jsonb_build_object(
                    'estado', 'success',
                    'codigo', 201,
                    'mensaje', 'Registro agregado correctamente'
                );

            ELSIF pi_tipo_alerta = 3 THEN
                -- Buscar alertas activas y resolverlas
                FOR alerta IN
                    SELECT id, dispositivo_id, area_id, habitacion_id,
                           codigo_cama, tipo_alerta, fecha_registro
                    FROM public.alertas
                    WHERE dispositivo_id = v_dispositivo_id
                    AND area_id = pi_area_id
                    AND habitacion_id = pi_habitacion_id
                    AND codigo_cama = pi_codigo_cama
                    AND estado_alerta = TRUE
                LOOP
                    -- Resolver la alerta
                    UPDATE public.alertas
                    SET estado_alerta = FALSE, fecha_modificacion = CURRENT_TIMESTAMP
                    WHERE id = alerta.id;

                    -- Registrar en historial_alertas
                    INSERT INTO public.historial_alertas (
                        alerta_id, dispositivo_id, area_id, habitacion_id,
                        codigo_cama, tipo_alerta, tiempo_respuesta,
                        usuario_respuesta_id, fecha_alerta, fecha_respuesta
                    ) VALUES (
                        alerta.id, alerta.dispositivo_id, alerta.area_id,
                        alerta.habitacion_id, alerta.codigo_cama, alerta.tipo_alerta,
                        CURRENT_TIMESTAMP - alerta.fecha_registro,
                        NULL,
                        alerta.fecha_registro, CURRENT_TIMESTAMP
                    );

                    v_alertas_resueltas := v_alertas_resueltas + 1;
                END LOOP;

                IF v_alertas_resueltas > 0 THEN
                    RETURN jsonb_build_object(
                        'estado', 'success',
                        'codigo', 200,
                        'mensaje', 'Registros actualizados correctamente'
                    );
                ELSE
                    RETURN jsonb_build_object(
                        'estado', 'error',
                        'codigo', 404,
                        'mensaje', 'No hay registros por atender'
                    );
                END IF;

            END IF;

        ELSE
            RETURN jsonb_build_object(
                'estado', 'error',
                'codigo', 404,
                'mensaje', 'Dispositivo no encontrado'
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
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- PASO 6: Actualizar sp_cargar_data_essi
-- Registra cambios de ocupación en historial_ocupacion
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
    v_existing_nombre VARCHAR;
    v_new_id INT;
BEGIN
    -- Buscar si existe un registro activo para esta cama
    SELECT id, "nroDocIdePac", "apeNomPac"
    INTO v_existing_id, v_existing_paciente, v_existing_nombre
    FROM public.camas_essi
    WHERE "codHabCama" = p_codhabcama
      AND "codHab" = p_codhab
      AND "codCama" = p_codcama
      AND estado = TRUE
    LIMIT 1;

    IF v_existing_id IS NOT NULL THEN
        -- Existe un registro activo para esta cama
        IF v_existing_paciente = p_nrodocidepac THEN
            -- Mismo paciente: actualizar datos existentes
            UPDATE public.camas_essi
            SET "apeNomPac" = p_apenompac,
                "desEstCama" = p_desestcama,
                "desSerCama" = p_dessercama,
                "diashospi" = p_diashospi,
                "fechaIngreso" = p_fechaingreso,
                "nroHisCliCas" = p_nrohisclicas,
                "tipoDocIdePac" = p_tipodocidepac,
                fecha_modificacion = CURRENT_TIMESTAMP
            WHERE id = v_existing_id;

            RETURN jsonb_build_object(
                'estado', 'success',
                'codigo', 200,
                'mensaje', 'Registro actualizado'
            );
        ELSE
            -- Paciente diferente: desactivar el viejo e insertar nuevo

            -- Registrar EGRESO del paciente anterior
            IF COALESCE(v_existing_nombre, '') != '' THEN
                INSERT INTO public.historial_ocupacion (
                    cama_essi_id, codhabcama, codhab, codcama,
                    paciente, nrodocidepac, accion
                ) VALUES (
                    v_existing_id, p_codhabcama, p_codhab, p_codcama,
                    v_existing_nombre, v_existing_paciente, 'EGRESO'
                );
            END IF;

            UPDATE public.camas_essi
            SET estado = FALSE,
                fecha_modificacion = CURRENT_TIMESTAMP
            WHERE id = v_existing_id;

            INSERT INTO public.camas_essi (
                "codHabCama", "codHab", "codCama", "apeNomPac",
                "desEstCama", "desSerCama", "diashospi", "fechaIngreso",
                "nroDocIdePac", "nroHisCliCas", "tipoDocIdePac",
                estado, fecha_registro, fecha_modificacion
            ) VALUES (
                p_codhabcama, p_codhab, p_codcama, p_apenompac,
                p_desestcama, p_dessercama, p_diashospi, p_fechaingreso,
                p_nrodocidepac, p_nrohisclicas, p_tipodocidepac,
                TRUE, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
            ) RETURNING id INTO v_new_id;

            -- Registrar INGRESO del nuevo paciente
            IF COALESCE(p_apenompac, '') != '' THEN
                INSERT INTO public.historial_ocupacion (
                    cama_essi_id, codhabcama, codhab, codcama,
                    paciente, nrodocidepac, accion
                ) VALUES (
                    v_new_id, p_codhabcama, p_codhab, p_codcama,
                    p_apenompac, p_nrodocidepac, 'INGRESO'
                );
            END IF;

            RETURN jsonb_build_object(
                'estado', 'success',
                'codigo', 200,
                'mensaje', 'Paciente cambiado en cama'
            );
        END IF;
    ELSE
        -- No existe registro activo: insertar nuevo
        INSERT INTO public.camas_essi (
            "codHabCama", "codHab", "codCama", "apeNomPac",
            "desEstCama", "desSerCama", "diashospi", "fechaIngreso",
            "nroDocIdePac", "nroHisCliCas", "tipoDocIdePac",
            estado, fecha_registro, fecha_modificacion
        ) VALUES (
            p_codhabcama, p_codhab, p_codcama, p_apenompac,
            p_desestcama, p_dessercama, p_diashospi, p_fechaingreso,
            p_nrodocidepac, p_nrohisclicas, p_tipodocidepac,
            TRUE, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
        ) RETURNING id INTO v_new_id;

        -- Registrar INGRESO del paciente
        IF COALESCE(p_apenompac, '') != '' THEN
            INSERT INTO public.historial_ocupacion (
                cama_essi_id, codhabcama, codhab, codcama,
                paciente, nrodocidepac, accion
            ) VALUES (
                v_new_id, p_codhabcama, p_codhab, p_codcama,
                p_apenompac, p_nrodocidepac, 'INGRESO'
            );
        END IF;

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

        UPDATE public.camas_essi
        SET "apeNomPac" = p_apenompac,
            "desEstCama" = p_desestcama,
            "desSerCama" = p_dessercama,
            "diashospi" = p_diashospi,
            "fechaIngreso" = p_fechaingreso,
            "nroDocIdePac" = p_nrodocidepac,
            "nroHisCliCas" = p_nrohisclicas,
            "tipoDocIdePac" = p_tipodocidepac,
            estado = TRUE,
            fecha_modificacion = CURRENT_TIMESTAMP
        WHERE "codHabCama" = p_codhabcama
          AND "codHab" = p_codhab
          AND "codCama" = p_codcama
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
-- PASO 7: Verificación
-- =====================================================
DO $$
DECLARE
    tabla_count INT;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'VERIFICACION - MIGRACION 20';
    RAISE NOTICE '========================================';

    -- Verificar tablas
    SELECT COUNT(*) INTO tabla_count
    FROM information_schema.tables
    WHERE table_schema = 'public'
    AND table_name IN ('historial_notas', 'historial_alertas', 'historial_ocupacion');

    RAISE NOTICE 'Tablas de historial creadas: %/3', tabla_count;

    -- Verificar sp_editar_nota tiene 4 parámetros
    RAISE NOTICE 'sp_editar_nota: verificando...';
    PERFORM proname FROM pg_proc
    WHERE proname = 'sp_editar_nota'
    AND pronargs = 4;
    IF FOUND THEN
        RAISE NOTICE '  OK - 4 parametros (id, nota, fecha_nota, usuario_id)';
    ELSE
        RAISE NOTICE '  ERROR - No se encontro con 4 parametros';
    END IF;

    -- Verificar sp_agregar_registro
    RAISE NOTICE 'sp_agregar_registro: verificando...';
    PERFORM proname FROM pg_proc
    WHERE proname = 'sp_agregar_registro'
    AND pronargs = 5;
    IF FOUND THEN
        RAISE NOTICE '  OK - 5 parametros';
    ELSE
        RAISE NOTICE '  ERROR - No se encontro con 5 parametros';
    END IF;

    -- Verificar sp_cargar_data_essi
    RAISE NOTICE 'sp_cargar_data_essi: verificando...';
    PERFORM proname FROM pg_proc
    WHERE proname = 'sp_cargar_data_essi'
    AND pronargs = 11;
    IF FOUND THEN
        RAISE NOTICE '  OK - 11 parametros';
    ELSE
        RAISE NOTICE '  ERROR - No se encontro con 11 parametros';
    END IF;

    RAISE NOTICE '';
    RAISE NOTICE 'MIGRACION 20 COMPLETADA';
    RAISE NOTICE '========================================';
END $$;
