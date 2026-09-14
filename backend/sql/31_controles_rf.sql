-- ============================================
-- Migration 31: Controles RF (DIP Switch)
-- Tabla para documentar configuracion RF de controles remotos
-- ============================================

-- Tabla de controles RF
CREATE TABLE IF NOT EXISTS controles_rf (
  id SERIAL PRIMARY KEY,
  habitacion_id INTEGER NOT NULL,
  cama VARCHAR(10) NOT NULL,
  dip_config JSONB NOT NULL DEFAULT '[false, false, false, false, false, false, false, false]'::jsonb,
  descripcion VARCHAR(255) DEFAULT '',
  estado BOOLEAN NOT NULL DEFAULT true,
  fecha_registro TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  fecha_modificacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Un solo control por habitacion+cama (activos)
CREATE UNIQUE INDEX IF NOT EXISTS idx_controles_rf_hab_cama
  ON controles_rf(habitacion_id, cama) WHERE estado = true;

CREATE INDEX IF NOT EXISTS idx_controles_rf_estado ON controles_rf(estado);

-- ============================================
-- sp_listar_controles_rf
-- Lista todos los controles RF activos
-- ============================================
CREATE OR REPLACE FUNCTION sp_listar_controles_rf()
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
  v_result JSONB;
BEGIN
  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'id', c.id,
      'habitacion_id', c.habitacion_id,
      'cama', c.cama,
      'dip_config', c.dip_config,
      'descripcion', c.descripcion,
      'fecha_registro', c.fecha_registro,
      'fecha_modificacion', c.fecha_modificacion
    ) ORDER BY c.habitacion_id, c.cama
  ), '[]'::jsonb)
  INTO v_result
  FROM controles_rf c
  WHERE c.estado = true;

  RETURN jsonb_build_object(
    'estado', 'success',
    'codigo', 200,
    'mensaje', v_result
  );
END;
$$;

-- ============================================
-- sp_agregar_control_rf
-- Agrega o actualiza un control RF
-- Si p_id = 0 → INSERT, si p_id > 0 → UPDATE
-- ============================================
CREATE OR REPLACE FUNCTION sp_agregar_control_rf(
  p_id INTEGER,
  p_habitacion_id INTEGER,
  p_cama VARCHAR,
  p_dip_config JSONB,
  p_descripcion VARCHAR,
  p_estado BOOLEAN
)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
  v_id INTEGER;
BEGIN
  IF p_id = 0 OR p_id IS NULL THEN
    -- INSERT nuevo control
    INSERT INTO controles_rf (habitacion_id, cama, dip_config, descripcion, estado)
    VALUES (p_habitacion_id, p_cama, p_dip_config, p_descripcion, p_estado)
    RETURNING id INTO v_id;

    RETURN jsonb_build_object(
      'estado', 'success',
      'codigo', 201,
      'mensaje', 'Control RF registrado correctamente',
      'id', v_id
    );
  ELSE
    -- UPDATE control existente
    UPDATE controles_rf
    SET habitacion_id = p_habitacion_id,
        cama = p_cama,
        dip_config = p_dip_config,
        descripcion = p_descripcion,
        estado = p_estado,
        fecha_modificacion = CURRENT_TIMESTAMP
    WHERE id = p_id;

    IF NOT FOUND THEN
      RETURN jsonb_build_object(
        'estado', 'error',
        'codigo', 404,
        'mensaje', 'Control RF no encontrado'
      );
    END IF;

    RETURN jsonb_build_object(
      'estado', 'success',
      'codigo', 200,
      'mensaje', 'Control RF actualizado correctamente'
    );
  END IF;

EXCEPTION
  WHEN unique_violation THEN
    RETURN jsonb_build_object(
      'estado', 'error',
      'codigo', 409,
      'mensaje', 'Ya existe un control RF para esta habitacion y cama'
    );
  WHEN OTHERS THEN
    RETURN jsonb_build_object(
      'estado', 'error',
      'codigo', 500,
      'mensaje', SQLERRM
    );
END;
$$;

-- ============================================
-- sp_eliminar_control_rf
-- Soft delete de un control RF
-- ============================================
CREATE OR REPLACE FUNCTION sp_eliminar_control_rf(p_id INTEGER)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
BEGIN
  UPDATE controles_rf
  SET estado = false, fecha_modificacion = CURRENT_TIMESTAMP
  WHERE id = p_id AND estado = true;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'estado', 'error',
      'codigo', 404,
      'mensaje', 'Control RF no encontrado'
    );
  END IF;

  RETURN jsonb_build_object(
    'estado', 'success',
    'codigo', 200,
    'mensaje', 'Control RF eliminado correctamente'
  );

EXCEPTION
  WHEN OTHERS THEN
    RETURN jsonb_build_object(
      'estado', 'error',
      'codigo', 500,
      'mensaje', SQLERRM
    );
END;
$$;
