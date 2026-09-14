-- =====================================================
-- MIGRACION 27: Heartbeat para dispositivos ESP32
-- =====================================================
-- Agrega columnas de monitoreo a esp32_dispositivos
-- y stored procedures para heartbeat y listar dispositivos.
-- =====================================================

-- =====================================================
-- PARTE 1: Nuevas columnas
-- =====================================================

ALTER TABLE esp32_dispositivos
  ADD COLUMN IF NOT EXISTS tipo_dispositivo VARCHAR(20) DEFAULT 'desconocido',
  ADD COLUMN IF NOT EXISTS habitacion_id INTEGER DEFAULT NULL,
  ADD COLUMN IF NOT EXISTS relay_estado BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS uptime_segundos INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS rssi INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS ultimo_heartbeat TIMESTAMP DEFAULT NULL;

-- =====================================================
-- PARTE 2: SP Heartbeat (sin autenticacion)
-- =====================================================
-- Recibe datos del ESP32 y actualiza o crea el registro.
-- No requiere token JWT - el ESP32 luces se identifica
-- por su numero_serial y MAC.

CREATE OR REPLACE FUNCTION public.sp_heartbeat_dispositivo(
  pi_serial TEXT,
  pi_mac TEXT,
  pi_ip TEXT,
  pi_tipo TEXT,
  pi_habitacion_id INT,
  pi_relay BOOL,
  pi_uptime INT,
  pi_rssi INT
)
RETURNS JSONB AS $$
DECLARE
  dispositivo_existe BOOLEAN;
BEGIN
  SELECT EXISTS(
    SELECT 1 FROM public.esp32_dispositivos WHERE numero_serial = pi_serial
  ) INTO dispositivo_existe;

  IF dispositivo_existe THEN
    UPDATE public.esp32_dispositivos SET
      direccion_mac = pi_mac,
      ip = pi_ip,
      tipo_dispositivo = pi_tipo,
      habitacion_id = pi_habitacion_id,
      relay_estado = pi_relay,
      uptime_segundos = pi_uptime,
      rssi = pi_rssi,
      ultimo_heartbeat = CURRENT_TIMESTAMP,
      estado = true,
      fecha_modificacion = CURRENT_TIMESTAMP
    WHERE numero_serial = pi_serial;

    RETURN jsonb_build_object('estado', 'success', 'codigo', 200, 'mensaje', 'Heartbeat actualizado');
  ELSE
    INSERT INTO public.esp32_dispositivos (
      numero_serial, direccion_mac, ip, estado, tipo_dispositivo,
      habitacion_id, relay_estado, uptime_segundos, rssi,
      ultimo_heartbeat, fecha_registro, fecha_modificacion
    ) VALUES (
      pi_serial, pi_mac, pi_ip, true, pi_tipo,
      pi_habitacion_id, pi_relay, pi_uptime, pi_rssi,
      CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
    );

    RETURN jsonb_build_object('estado', 'success', 'codigo', 201, 'mensaje', 'Dispositivo registrado via heartbeat');
  END IF;

EXCEPTION
  WHEN OTHERS THEN
    RETURN jsonb_build_object('estado', 'error', 'codigo', 500, 'mensaje', SQLERRM);
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- PARTE 3: SP Listar dispositivos
-- =====================================================
-- Retorna todos los dispositivos con su estado online
-- (online = ultimo heartbeat hace menos de 10 minutos)

CREATE OR REPLACE FUNCTION public.sp_listar_dispositivos()
RETURNS JSONB AS $$
DECLARE
  dispositivos_json JSONB := '[]'::jsonb;
  dispositivo RECORD;
BEGIN
  FOR dispositivo IN
    SELECT
      d.id,
      d.numero_serial,
      d.direccion_mac,
      d.ip,
      d.estado,
      d.tipo_dispositivo,
      d.habitacion_id,
      d.relay_estado,
      d.uptime_segundos,
      d.rssi,
      d.ultimo_heartbeat,
      d.fecha_registro,
      CASE
        WHEN d.ultimo_heartbeat IS NOT NULL
          AND d.ultimo_heartbeat > (CURRENT_TIMESTAMP - INTERVAL '10 minutes')
        THEN true
        ELSE false
      END AS online
    FROM public.esp32_dispositivos d
    WHERE d.estado = true
    ORDER BY d.ultimo_heartbeat DESC NULLS LAST
  LOOP
    dispositivos_json := dispositivos_json || jsonb_build_object(
      'id', dispositivo.id,
      'numero_serial', dispositivo.numero_serial,
      'direccion_mac', dispositivo.direccion_mac,
      'ip', dispositivo.ip,
      'tipo_dispositivo', dispositivo.tipo_dispositivo,
      'habitacion_id', dispositivo.habitacion_id,
      'relay_estado', dispositivo.relay_estado,
      'uptime_segundos', dispositivo.uptime_segundos,
      'rssi', dispositivo.rssi,
      'ultimo_heartbeat', dispositivo.ultimo_heartbeat,
      'online', dispositivo.online,
      'fecha_registro', dispositivo.fecha_registro
    );
  END LOOP;

  RETURN jsonb_build_object('estado', 'success', 'codigo', 200, 'mensaje', dispositivos_json);

EXCEPTION
  WHEN OTHERS THEN
    RETURN jsonb_build_object('estado', 'error', 'codigo', 500, 'mensaje', SQLERRM);
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- FIN MIGRACION 27
-- =====================================================
