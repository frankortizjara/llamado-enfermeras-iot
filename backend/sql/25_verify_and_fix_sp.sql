-- =====================================================
-- VERIFICACION Y CORRECCION DE STORED PROCEDURES
-- Ejecutar para asegurar que los SPs registran historial
-- =====================================================

SET search_path TO public;

-- =====================================================
-- PASO 1: Verificar estado actual
-- =====================================================
DO $$
DECLARE
    v_sp_code TEXT;
    v_has_historial BOOLEAN := FALSE;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'VERIFICANDO STORED PROCEDURES';
    RAISE NOTICE '========================================';

    -- Obtener el codigo de sp_agregar_registro
    SELECT pg_get_functiondef(oid) INTO v_sp_code
    FROM pg_proc
    WHERE proname = 'sp_agregar_registro'
    AND pronargs = 5
    LIMIT 1;

    IF v_sp_code IS NOT NULL THEN
        v_has_historial := v_sp_code ILIKE '%historial_alertas%';
        IF v_has_historial THEN
            RAISE NOTICE 'sp_agregar_registro: OK - Tiene registro en historial_alertas';
        ELSE
            RAISE NOTICE 'sp_agregar_registro: INCORRECTO - NO registra en historial_alertas';
            RAISE NOTICE 'Ejecutando correccion...';
        END IF;
    ELSE
        RAISE NOTICE 'sp_agregar_registro: NO ENCONTRADO';
    END IF;

    RAISE NOTICE '========================================';
END $$;

-- =====================================================
-- PASO 2: Recrear sp_agregar_registro con historial
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
        -- Buscar el dispositivo por 'serial' O 'numero_serial'
        SELECT id INTO v_dispositivo_id
        FROM public.esp32_dispositivos
        WHERE serial = pi_numero_serial
           OR numero_serial = pi_numero_serial
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
                        'mensaje', 'Registro aun sin atender'
                    );
                END LOOP;

                -- Si no se encontro ningún registro activo, insertar nuevo
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

                    -- IMPORTANTE: Registrar en historial_alertas
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
                        'mensaje', format('Se resolvieron %s alertas', v_alertas_resueltas)
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
-- PASO 3: Verificar tablas de historial existen
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
-- PASO 4: Verificacion final
-- =====================================================
DO $$
DECLARE
    v_sp_code TEXT;
    v_has_historial BOOLEAN := FALSE;
    v_count_notas INT;
    v_count_alertas INT;
    v_count_ocupacion INT;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'VERIFICACION FINAL';
    RAISE NOTICE '========================================';

    -- Verificar SP
    SELECT pg_get_functiondef(oid) INTO v_sp_code
    FROM pg_proc
    WHERE proname = 'sp_agregar_registro'
    AND pronargs = 5
    LIMIT 1;

    v_has_historial := v_sp_code ILIKE '%historial_alertas%';
    IF v_has_historial THEN
        RAISE NOTICE 'sp_agregar_registro: CORRECTO';
    ELSE
        RAISE NOTICE 'sp_agregar_registro: ERROR - revisar manualmente';
    END IF;

    -- Contar registros en historiales
    SELECT COUNT(*) INTO v_count_notas FROM historial_notas;
    SELECT COUNT(*) INTO v_count_alertas FROM historial_alertas;
    SELECT COUNT(*) INTO v_count_ocupacion FROM historial_ocupacion;

    RAISE NOTICE '';
    RAISE NOTICE 'Registros en tablas de historial:';
    RAISE NOTICE '  historial_notas: %', v_count_notas;
    RAISE NOTICE '  historial_alertas: %', v_count_alertas;
    RAISE NOTICE '  historial_ocupacion: %', v_count_ocupacion;

    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'CORRECCION COMPLETADA';
    RAISE NOTICE '';
    RAISE NOTICE 'IMPORTANTE: Las alertas solo se registran';
    RAISE NOTICE 'en historial_alertas cuando:';
    RAISE NOTICE '  1. Se resuelven via API con tipo_alerta=3';
    RAISE NOTICE '  2. Se usa el boton "Reconocer Alerta"';
    RAISE NOTICE '';
    RAISE NOTICE 'NO se registran si se hace UPDATE directo';
    RAISE NOTICE 'a la tabla alertas.';
    RAISE NOTICE '========================================';
END $$;
