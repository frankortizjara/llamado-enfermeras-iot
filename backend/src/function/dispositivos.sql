-- ============================================
-- Stored Procedures para Dispositivos ESP32
-- Sistema de Llamado de Enfermeras
-- CORREGIDO: Nombres de columnas actualizados
-- ============================================

CREATE OR REPLACE FUNCTION public.sp_agregar_esp32(
    pi_numero_serial TEXT,
    pi_direccion_mac TEXT,
    pi_ip_wifi TEXT,
    pi_estado BOOL
)
RETURNS JSONB AS $$
DECLARE
    resultado JSONB;
    dispositivo_existe BOOLEAN;
    nuevo_id INT;
BEGIN
    -- Verificar si el dispositivo ya existe por serial o mac
    SELECT EXISTS(
        SELECT 1
        FROM public.esp32_dispositivos
        WHERE numero_serial = pi_numero_serial
           OR direccion_mac = pi_direccion_mac
    ) INTO dispositivo_existe;

    IF dispositivo_existe THEN
        -- Actualizar dispositivo existente
        UPDATE public.esp32_dispositivos
        SET estado = pi_estado,
            ip = pi_ip_wifi,
            fecha_modificacion = CURRENT_TIMESTAMP
        WHERE numero_serial = pi_numero_serial
           OR direccion_mac = pi_direccion_mac;

        IF FOUND THEN
            resultado := jsonb_build_object(
                'estado', 'success',
                'codigo', 200,
                'mensaje', 'Dispositivo actualizado'
            );
        ELSE
            resultado := jsonb_build_object(
                'estado', 'error',
                'codigo', 404,
                'mensaje', 'Dispositivo no encontrado'
            );
        END IF;
    ELSE
        -- Insertar un nuevo dispositivo
        INSERT INTO public.esp32_dispositivos (numero_serial, direccion_mac, ip, estado, fecha_registro, fecha_modificacion)
        VALUES (pi_numero_serial, pi_direccion_mac, pi_ip_wifi, pi_estado, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
        RETURNING id INTO nuevo_id;

        resultado := jsonb_build_object(
            'estado', 'success',
            'codigo', 201,
            'mensaje', 'Dispositivo creado',
            'id', nuevo_id
        );
    END IF;

    RETURN resultado;

EXCEPTION
    WHEN unique_violation THEN
        RETURN jsonb_build_object(
            'estado', 'error',
            'codigo', 409,
            'mensaje', 'El dispositivo ya está registrado con el mismo serial o mac'
        );
    WHEN OTHERS THEN
        RETURN jsonb_build_object(
            'estado', 'error',
            'codigo', 500,
            'mensaje', SQLERRM
        );
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- SP para agregar registro de alerta
-- ============================================

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
        -- Buscar el dispositivo por numero_serial (CORREGIDO)
        SELECT id
        INTO v_dispositivo_id
        FROM public.esp32_dispositivos
        WHERE numero_serial = pi_numero_serial;

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
                IF NOT FOUND THEN
                    INSERT INTO public.alertas (
                        dispositivo_id, area_id, habitacion_id, codigo_cama, tipo_alerta, fecha_registro, fecha_modificacion
                    ) VALUES (
                        v_dispositivo_id, pi_area_id, pi_habitacion_id, pi_codigo_cama, pi_tipo_alerta, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
                    );

                    RETURN jsonb_build_object(
                        'estado', 'success',
                        'codigo', 201,
                        'mensaje', 'Registro agregado correctamente'
                    );
                END IF;

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
