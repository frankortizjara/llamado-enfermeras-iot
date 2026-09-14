-- =====================================================
-- MIGRACION 28: Fix reemplazo de dispositivos + Eventos
-- =====================================================
-- 1. Nueva tabla dispositivo_eventos para tracking
-- 2. Columna ultimo_estado_online en esp32_dispositivos
-- 3. Fix sp_heartbeat_dispositivo: desactiva dispositivo
--    anterior cuando otro toma la misma habitacion+tipo
-- 4. Modifica sp_listar_dispositivos: detecta desconexiones
-- 5. Nuevas SPs: estadisticas y eventos por dispositivo
-- =====================================================

-- =====================================================
-- PARTE 1: Nueva tabla de eventos
-- =====================================================

CREATE TABLE IF NOT EXISTS dispositivo_eventos (
  id SERIAL PRIMARY KEY,
  dispositivo_id INTEGER REFERENCES esp32_dispositivos(id) ON DELETE SET NULL,
  numero_serial VARCHAR(12) NOT NULL,
  tipo_evento VARCHAR(20) NOT NULL,  -- 'online', 'offline', 'reemplazo'
  detalles JSONB DEFAULT '{}'::jsonb,
  fecha TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_eventos_serial ON dispositivo_eventos(numero_serial);
CREATE INDEX IF NOT EXISTS idx_eventos_fecha ON dispositivo_eventos(fecha DESC);
CREATE INDEX IF NOT EXISTS idx_eventos_tipo ON dispositivo_eventos(tipo_evento);

-- =====================================================
-- PARTE 2: Nueva columna para detectar transiciones
-- =====================================================

ALTER TABLE esp32_dispositivos
  ADD COLUMN IF NOT EXISTS ultimo_estado_online BOOLEAN DEFAULT false;

-- =====================================================
-- PARTE 3: Fix sp_heartbeat_dispositivo
-- =====================================================
-- Ahora: al recibir heartbeat, si hay otro dispositivo
-- activo con la misma habitacion_id + tipo_dispositivo,
-- lo desactiva y registra evento de reemplazo.
-- Tambien detecta reconexion (estaba offline -> online).

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
  v_device_id INTEGER;
  v_was_online BOOLEAN;
  v_old_heartbeat TIMESTAMP;
  v_old_serial TEXT;
  v_old_id INTEGER;
BEGIN
  -- Verificar si el dispositivo ya existe por serial
  SELECT EXISTS(
    SELECT 1 FROM public.esp32_dispositivos WHERE numero_serial = pi_serial
  ) INTO dispositivo_existe;

  IF dispositivo_existe THEN
    -- Obtener estado anterior para detectar reconexion
    SELECT id, ultimo_estado_online, ultimo_heartbeat
    INTO v_device_id, v_was_online, v_old_heartbeat
    FROM public.esp32_dispositivos
    WHERE numero_serial = pi_serial;

    -- Actualizar el dispositivo
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
      ultimo_estado_online = true,
      fecha_modificacion = CURRENT_TIMESTAMP
    WHERE numero_serial = pi_serial;

    -- Detectar reconexion: estaba offline y ahora manda heartbeat
    IF v_was_online = false OR v_old_heartbeat IS NULL
       OR v_old_heartbeat < (CURRENT_TIMESTAMP - INTERVAL '10 minutes') THEN
      INSERT INTO dispositivo_eventos (dispositivo_id, numero_serial, tipo_evento, detalles)
      VALUES (v_device_id, pi_serial, 'online', jsonb_build_object(
        'ip', pi_ip,
        'mac', pi_mac,
        'tipo', pi_tipo,
        'habitacion_id', pi_habitacion_id,
        'rssi', pi_rssi,
        'offline_desde', COALESCE(v_old_heartbeat::text, 'nunca')
      ));
    END IF;

  ELSE
    -- Insertar nuevo dispositivo
    INSERT INTO public.esp32_dispositivos (
      numero_serial, direccion_mac, ip, estado, tipo_dispositivo,
      habitacion_id, relay_estado, uptime_segundos, rssi,
      ultimo_heartbeat, ultimo_estado_online, fecha_registro, fecha_modificacion
    ) VALUES (
      pi_serial, pi_mac, pi_ip, true, pi_tipo,
      pi_habitacion_id, pi_relay, pi_uptime, pi_rssi,
      CURRENT_TIMESTAMP, true, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
    )
    RETURNING id INTO v_device_id;

    -- Registrar evento de primer registro
    INSERT INTO dispositivo_eventos (dispositivo_id, numero_serial, tipo_evento, detalles)
    VALUES (v_device_id, pi_serial, 'online', jsonb_build_object(
      'ip', pi_ip,
      'mac', pi_mac,
      'tipo', pi_tipo,
      'habitacion_id', pi_habitacion_id,
      'primer_registro', true
    ));
  END IF;

  -- ====================================================
  -- REEMPLAZO: Desactivar otros dispositivos con misma
  -- habitacion_id + tipo_dispositivo pero diferente serial
  -- ====================================================
  IF pi_habitacion_id IS NOT NULL AND pi_tipo IS NOT NULL THEN
    FOR v_old_id, v_old_serial IN
      SELECT id, numero_serial
      FROM public.esp32_dispositivos
      WHERE habitacion_id = pi_habitacion_id
        AND tipo_dispositivo = pi_tipo
        AND numero_serial != pi_serial
        AND estado = true
    LOOP
      -- Desactivar el dispositivo anterior
      UPDATE public.esp32_dispositivos
      SET estado = false,
          ultimo_estado_online = false,
          fecha_modificacion = CURRENT_TIMESTAMP
      WHERE id = v_old_id;

      -- Registrar evento de reemplazo en el dispositivo viejo
      INSERT INTO dispositivo_eventos (dispositivo_id, numero_serial, tipo_evento, detalles)
      VALUES (v_old_id, v_old_serial, 'reemplazo', jsonb_build_object(
        'reemplazado_por', pi_serial,
        'nuevo_mac', pi_mac,
        'habitacion_id', pi_habitacion_id,
        'tipo', pi_tipo
      ));
    END LOOP;
  END IF;

  RETURN jsonb_build_object('estado', 'success', 'codigo', 200, 'mensaje', 'Heartbeat actualizado');

EXCEPTION
  WHEN OTHERS THEN
    RETURN jsonb_build_object('estado', 'error', 'codigo', 500, 'mensaje', SQLERRM);
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- PARTE 4: Modificar sp_listar_dispositivos
-- =====================================================
-- Ahora detecta dispositivos que pasaron de online a
-- offline y registra el evento correspondiente.

CREATE OR REPLACE FUNCTION public.sp_listar_dispositivos()
RETURNS JSONB AS $$
DECLARE
  dispositivos_json JSONB := '[]'::jsonb;
  dispositivo RECORD;
  v_online BOOLEAN;
BEGIN
  -- Detectar transiciones offline y registrar eventos
  UPDATE public.esp32_dispositivos d
  SET ultimo_estado_online = false
  WHERE d.estado = true
    AND d.ultimo_estado_online = true
    AND (d.ultimo_heartbeat IS NULL
         OR d.ultimo_heartbeat <= (CURRENT_TIMESTAMP - INTERVAL '10 minutes'));

  -- Registrar eventos offline para los que cambiaron
  INSERT INTO dispositivo_eventos (dispositivo_id, numero_serial, tipo_evento, detalles)
  SELECT d.id, d.numero_serial, 'offline', jsonb_build_object(
    'ultimo_heartbeat', d.ultimo_heartbeat::text,
    'ip', d.ip,
    'tipo', d.tipo_dispositivo,
    'habitacion_id', d.habitacion_id
  )
  FROM public.esp32_dispositivos d
  WHERE d.estado = true
    AND d.ultimo_estado_online = false
    AND (d.ultimo_heartbeat IS NULL
         OR d.ultimo_heartbeat <= (CURRENT_TIMESTAMP - INTERVAL '10 minutes'))
    AND NOT EXISTS (
      SELECT 1 FROM dispositivo_eventos e
      WHERE e.numero_serial = d.numero_serial
        AND e.tipo_evento = 'offline'
        AND e.fecha > d.ultimo_heartbeat
    );

  -- Retornar listado con estado online calculado
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
-- PARTE 5: SP Estadisticas de dispositivos
-- =====================================================
-- Retorna estadisticas agregadas por dispositivo
-- en un rango de fechas.

CREATE OR REPLACE FUNCTION public.sp_estadisticas_dispositivos(
  pi_fecha_inicio TIMESTAMP,
  pi_fecha_fin TIMESTAMP
)
RETURNS JSONB AS $$
DECLARE
  resultado JSONB := '[]'::jsonb;
  reg RECORD;
BEGIN
  FOR reg IN
    SELECT
      d.id,
      d.numero_serial,
      d.direccion_mac,
      d.ip,
      d.tipo_dispositivo,
      d.habitacion_id,
      d.estado,
      d.ultimo_heartbeat,
      d.fecha_registro,
      CASE
        WHEN d.ultimo_heartbeat IS NOT NULL
          AND d.ultimo_heartbeat > (CURRENT_TIMESTAMP - INTERVAL '10 minutes')
        THEN true
        ELSE false
      END AS online,
      COALESCE((
        SELECT COUNT(*)
        FROM dispositivo_eventos e
        WHERE e.numero_serial = d.numero_serial
          AND e.tipo_evento = 'offline'
          AND e.fecha BETWEEN pi_fecha_inicio AND pi_fecha_fin
      ), 0) AS total_desconexiones,
      COALESCE((
        SELECT COUNT(*)
        FROM dispositivo_eventos e
        WHERE e.numero_serial = d.numero_serial
          AND e.tipo_evento = 'online'
          AND e.fecha BETWEEN pi_fecha_inicio AND pi_fecha_fin
      ), 0) AS total_reconexiones,
      COALESCE((
        SELECT COUNT(*)
        FROM dispositivo_eventos e
        WHERE e.numero_serial = d.numero_serial
          AND e.tipo_evento = 'reemplazo'
          AND e.fecha BETWEEN pi_fecha_inicio AND pi_fecha_fin
      ), 0) AS total_reemplazos,
      (
        SELECT e.fecha
        FROM dispositivo_eventos e
        WHERE e.numero_serial = d.numero_serial
        ORDER BY e.fecha DESC
        LIMIT 1
      ) AS ultimo_evento_fecha,
      (
        SELECT e.tipo_evento
        FROM dispositivo_eventos e
        WHERE e.numero_serial = d.numero_serial
        ORDER BY e.fecha DESC
        LIMIT 1
      ) AS ultimo_evento_tipo
    FROM public.esp32_dispositivos d
    ORDER BY d.habitacion_id NULLS LAST, d.tipo_dispositivo
  LOOP
    resultado := resultado || jsonb_build_object(
      'id', reg.id,
      'numero_serial', reg.numero_serial,
      'direccion_mac', reg.direccion_mac,
      'ip', reg.ip,
      'tipo_dispositivo', reg.tipo_dispositivo,
      'habitacion_id', reg.habitacion_id,
      'estado', reg.estado,
      'online', reg.online,
      'ultimo_heartbeat', reg.ultimo_heartbeat,
      'fecha_registro', reg.fecha_registro,
      'total_desconexiones', reg.total_desconexiones,
      'total_reconexiones', reg.total_reconexiones,
      'total_reemplazos', reg.total_reemplazos,
      'ultimo_evento_fecha', reg.ultimo_evento_fecha,
      'ultimo_evento_tipo', reg.ultimo_evento_tipo
    );
  END LOOP;

  RETURN jsonb_build_object('estado', 'success', 'codigo', 200, 'mensaje', resultado);

EXCEPTION
  WHEN OTHERS THEN
    RETURN jsonb_build_object('estado', 'error', 'codigo', 500, 'mensaje', SQLERRM);
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- PARTE 6: SP Eventos por dispositivo
-- =====================================================

CREATE OR REPLACE FUNCTION public.sp_eventos_dispositivo(
  pi_serial TEXT,
  pi_fecha_inicio TIMESTAMP,
  pi_fecha_fin TIMESTAMP
)
RETURNS JSONB AS $$
DECLARE
  resultado JSONB := '[]'::jsonb;
  reg RECORD;
BEGIN
  FOR reg IN
    SELECT
      e.id,
      e.numero_serial,
      e.tipo_evento,
      e.detalles,
      e.fecha
    FROM dispositivo_eventos e
    WHERE e.numero_serial = pi_serial
      AND e.fecha BETWEEN pi_fecha_inicio AND pi_fecha_fin
    ORDER BY e.fecha DESC
    LIMIT 200
  LOOP
    resultado := resultado || jsonb_build_object(
      'id', reg.id,
      'numero_serial', reg.numero_serial,
      'tipo_evento', reg.tipo_evento,
      'detalles', reg.detalles,
      'fecha', reg.fecha
    );
  END LOOP;

  RETURN jsonb_build_object('estado', 'success', 'codigo', 200, 'mensaje', resultado);

EXCEPTION
  WHEN OTHERS THEN
    RETURN jsonb_build_object('estado', 'error', 'codigo', 500, 'mensaje', SQLERRM);
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- FIN MIGRACION 28
-- =====================================================
