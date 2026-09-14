-- =====================================================
-- MIGRACION 22: SP para reconocer alertas de habitacion
-- =====================================================
-- Permite que un usuario (jefe de area) reconozca todas
-- las alertas activas de una habitacion, registrando
-- quien atendio y el tiempo de respuesta.
-- =====================================================

SET search_path TO public;

CREATE OR REPLACE FUNCTION public.sp_reconocer_alertas_habitacion(
    pi_habitacion_id INT,
    pi_usuario_id INT
)
RETURNS JSONB AS $$
DECLARE
    alerta RECORD;
    v_alertas_reconocidas INT := 0;
    v_tiempo_respuesta INTERVAL;
BEGIN
    BEGIN
        -- Buscar todas las alertas activas de la habitacion
        FOR alerta IN
            SELECT id, dispositivo_id, area_id, habitacion_id,
                   codigo_cama, tipo_alerta, fecha_registro
            FROM public.alertas
            WHERE habitacion_id = pi_habitacion_id
              AND estado_alerta = TRUE
        LOOP
            -- Calcular tiempo de respuesta
            v_tiempo_respuesta := CURRENT_TIMESTAMP - alerta.fecha_registro;

            -- Registrar en historial_alertas con usuario que reconocio
            INSERT INTO public.historial_alertas (
                alerta_id, dispositivo_id, area_id, habitacion_id,
                codigo_cama, tipo_alerta, tiempo_respuesta,
                usuario_respuesta_id, fecha_alerta, fecha_respuesta
            ) VALUES (
                alerta.id, alerta.dispositivo_id, alerta.area_id,
                alerta.habitacion_id, alerta.codigo_cama, alerta.tipo_alerta,
                v_tiempo_respuesta, pi_usuario_id,
                alerta.fecha_registro, CURRENT_TIMESTAMP
            );

            -- Desactivar la alerta
            UPDATE public.alertas
            SET estado_alerta = FALSE,
                tiempo_respuesta = v_tiempo_respuesta,
                fecha_modificacion = CURRENT_TIMESTAMP
            WHERE id = alerta.id;

            v_alertas_reconocidas := v_alertas_reconocidas + 1;
        END LOOP;

        IF v_alertas_reconocidas > 0 THEN
            RETURN jsonb_build_object(
                'estado', 'success',
                'codigo', 200,
                'mensaje', format('%s alerta(s) reconocida(s)', v_alertas_reconocidas)
            );
        ELSE
            RETURN jsonb_build_object(
                'estado', 'error',
                'codigo', 404,
                'mensaje', 'No se encontraron alertas activas en esta habitacion'
            );
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN jsonb_build_object('estado', 'error', 'codigo', 500, 'mensaje', SQLERRM);
    END;
END;
$$ LANGUAGE plpgsql;

-- Verificacion
DO $$
BEGIN
    RAISE NOTICE 'Migracion 22: sp_reconocer_alertas_habitacion creado';
END $$;
