-- =====================================================
-- FIX: sp_agregar_registro para usar columna 'serial'
-- El CSV usa 'serial' y 'mac', no 'numero_serial'
-- =====================================================

SET search_path TO public;

-- Verificar qué columnas tiene la tabla
DO $$
DECLARE
    cols TEXT := '';
BEGIN
    SELECT string_agg(column_name, ', ')
    INTO cols
    FROM information_schema.columns
    WHERE table_name = 'esp32_dispositivos';

    RAISE NOTICE 'Columnas en esp32_dispositivos: %', cols;
END $$;

-- =====================================================
-- Actualizar sp_agregar_registro para buscar en 'serial'
-- =====================================================
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
                -- Buscar si hay alertas activas para este dispositivo
                FOR alerta IN
                    SELECT id
                    FROM public.alertas
                    WHERE dispositivo_id = v_dispositivo_id
                    AND area_id = pi_area_id
                    AND habitacion_id = pi_habitacion_id
                    AND codigo_cama = pi_codigo_cama
                    AND estado_alerta = TRUE
                LOOP
                    UPDATE public.alertas
                    SET estado_alerta = FALSE, fecha_modificacion = CURRENT_TIMESTAMP
                    WHERE id = alerta.id;
                END LOOP;

                IF FOUND THEN
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
-- TEST: Verificar dispositivos disponibles
-- =====================================================
DO $$
DECLARE
    rec RECORD;
    contador INT := 0;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'DISPOSITIVOS ESP32 DISPONIBLES';
    RAISE NOTICE '========================================';

    FOR rec IN
        SELECT id, serial, mac, ip
        FROM esp32_dispositivos
        WHERE serial IS NOT NULL
        ORDER BY id
        LIMIT 10
    LOOP
        contador := contador + 1;
        RAISE NOTICE 'ID: %, Serial: %, IP: %', rec.id, rec.serial, rec.ip;
    END LOOP;

    RAISE NOTICE '';
    RAISE NOTICE 'Total dispositivos con serial: %', contador;
    RAISE NOTICE '========================================';
END $$;

-- =====================================================
-- MOSTRAR SERIALES PARA USAR EN ALERTAS
-- =====================================================
SELECT id, serial, ip
FROM esp32_dispositivos
WHERE serial IS NOT NULL
ORDER BY id
LIMIT 10;
