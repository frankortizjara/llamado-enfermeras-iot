-- ============================================
-- FIX: Cumpleaños SP - incluir registros con area_id NULL (globales)
-- ============================================

CREATE OR REPLACE FUNCTION sp_listar_cumpleanos(p_area_id INTEGER)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
  v_resultado JSONB;
BEGIN
  SELECT jsonb_agg(
    jsonb_build_object(
      'id', c.id,
      'nombre', c.nombre,
      'cargo', c.cargo,
      'dia', c.dia,
      'mes', c.mes,
      'area_id', c.area_id
    ) ORDER BY c.mes, c.dia
  )
  INTO v_resultado
  FROM cumpleanos c
  WHERE c.estado = true
    AND (p_area_id IS NULL OR c.area_id IS NULL OR c.area_id = p_area_id);

  RETURN jsonb_build_object(
    'estado', 'success',
    'codigo', 200,
    'mensaje', COALESCE(v_resultado, '[]'::jsonb)
  );
END;
$$;

CREATE OR REPLACE FUNCTION sp_obtener_cumpleanos_hoy(p_dia INTEGER, p_mes INTEGER, p_area_id INTEGER)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
  v_resultado JSONB;
BEGIN
  SELECT jsonb_agg(
    jsonb_build_object(
      'id', c.id,
      'nombre', c.nombre,
      'cargo', c.cargo,
      'dia', c.dia,
      'mes', c.mes
    )
  )
  INTO v_resultado
  FROM cumpleanos c
  WHERE c.dia = p_dia AND c.mes = p_mes AND c.estado = true
    AND (p_area_id IS NULL OR c.area_id IS NULL OR c.area_id = p_area_id);

  RETURN jsonb_build_object(
    'estado', 'success',
    'codigo', 200,
    'mensaje', COALESCE(v_resultado, '[]'::jsonb)
  );
END;
$$;

-- ============================================
-- ADD: modo_display a avisos (permanente o periodico)
-- ============================================

ALTER TABLE avisos ADD COLUMN IF NOT EXISTS modo_display VARCHAR(20) DEFAULT 'periodico' CHECK (modo_display IN ('permanente', 'periodico'));

-- ============================================
-- ADD: Tabla de configuración TV
-- ============================================

CREATE TABLE IF NOT EXISTS config_tv (
  id SERIAL PRIMARY KEY,
  clave VARCHAR(100) UNIQUE NOT NULL,
  valor VARCHAR(255) NOT NULL,
  descripcion TEXT
);

-- Insertar configuraciones por defecto
INSERT INTO config_tv (clave, valor, descripcion) VALUES
  ('intervalo_efemerides', '40', 'Intervalo en minutos para mostrar efemérides'),
  ('intervalo_cumpleanos', '30', 'Intervalo en minutos para mostrar cumpleaños'),
  ('intervalo_avisos', '15', 'Intervalo en minutos para mostrar avisos periódicos'),
  ('duracion_overlay', '15', 'Duración en segundos de cada overlay')
ON CONFLICT (clave) DO NOTHING;

-- ============================================
-- SP: Obtener/Actualizar configuración TV
-- ============================================

CREATE OR REPLACE FUNCTION sp_obtener_config_tv()
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
  v_resultado JSONB;
BEGIN
  SELECT jsonb_object_agg(c.clave, c.valor)
  INTO v_resultado
  FROM config_tv c;

  RETURN jsonb_build_object(
    'estado', 'success',
    'codigo', 200,
    'mensaje', COALESCE(v_resultado, '{}'::jsonb)
  );
END;
$$;

CREATE OR REPLACE FUNCTION sp_actualizar_config_tv(p_clave VARCHAR(100), p_valor VARCHAR(255))
RETURNS JSONB
LANGUAGE plpgsql
AS $$
BEGIN
  UPDATE config_tv SET valor = p_valor WHERE clave = p_clave;

  IF NOT FOUND THEN
    INSERT INTO config_tv (clave, valor) VALUES (p_clave, p_valor);
  END IF;

  RETURN jsonb_build_object(
    'estado', 'success',
    'codigo', 200,
    'mensaje', 'Configuración actualizada'
  );
END;
$$;

-- ============================================
-- FIX: Actualizar SP agregar_aviso para incluir modo_display
-- ============================================

CREATE OR REPLACE FUNCTION sp_agregar_aviso(
  p_id INTEGER,
  p_titulo VARCHAR(255),
  p_mensaje TEXT,
  p_prioridad VARCHAR(20),
  p_area_id INTEGER,
  p_creado_por INTEGER,
  p_fecha_inicio DATE,
  p_fecha_fin DATE,
  p_estado BOOLEAN,
  p_modo_display VARCHAR(20) DEFAULT 'periodico'
)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
  v_id INTEGER;
BEGIN
  IF p_id IS NOT NULL AND p_id > 0 THEN
    UPDATE avisos
    SET titulo = p_titulo, mensaje = p_mensaje, prioridad = p_prioridad,
        area_id = p_area_id, fecha_inicio = p_fecha_inicio,
        fecha_fin = p_fecha_fin, estado = p_estado,
        modo_display = COALESCE(p_modo_display, 'periodico')
    WHERE id = p_id;
    v_id := p_id;
  ELSE
    INSERT INTO avisos (titulo, mensaje, prioridad, area_id, creado_por, fecha_inicio, fecha_fin, estado, modo_display)
    VALUES (p_titulo, p_mensaje, COALESCE(p_prioridad, 'normal'), p_area_id, p_creado_por,
            COALESCE(p_fecha_inicio, CURRENT_DATE), p_fecha_fin, COALESCE(p_estado, true),
            COALESCE(p_modo_display, 'periodico'))
    RETURNING id INTO v_id;
  END IF;

  RETURN jsonb_build_object(
    'estado', 'success',
    'codigo', 200,
    'mensaje', 'Aviso guardado correctamente',
    'id', v_id
  );
END;
$$;

-- ============================================
-- FIX: Actualizar SP listar_avisos para incluir modo_display
-- ============================================

CREATE OR REPLACE FUNCTION sp_listar_avisos(p_area_id INTEGER)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
  v_resultado JSONB;
BEGIN
  SELECT jsonb_agg(
    jsonb_build_object(
      'id', a.id,
      'titulo', a.titulo,
      'mensaje', a.mensaje,
      'prioridad', a.prioridad,
      'modo_display', COALESCE(a.modo_display, 'periodico'),
      'area_id', a.area_id,
      'creado_por', a.creado_por,
      'nombre_creador', u.nombre,
      'fecha_inicio', a.fecha_inicio,
      'fecha_fin', a.fecha_fin
    ) ORDER BY
      CASE a.prioridad
        WHEN 'muy_importante' THEN 1
        WHEN 'importante' THEN 2
        ELSE 3
      END,
      a.fecha_registro DESC
  )
  INTO v_resultado
  FROM avisos a
  LEFT JOIN usuarios u ON u.id = a.creado_por
  WHERE a.estado = true
    AND (p_area_id IS NULL OR a.area_id IS NULL OR a.area_id = p_area_id)
    AND a.fecha_inicio <= CURRENT_DATE
    AND (a.fecha_fin IS NULL OR a.fecha_fin >= CURRENT_DATE);

  RETURN jsonb_build_object(
    'estado', 'success',
    'codigo', 200,
    'mensaje', COALESCE(v_resultado, '[]'::jsonb)
  );
END;
$$;

-- ============================================
-- FIX: Actualizar SP contenido_tv para incluir modo_display en avisos
-- ============================================

CREATE OR REPLACE FUNCTION sp_obtener_contenido_tv(p_dia INTEGER, p_mes INTEGER, p_area_id INTEGER)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
  v_efemerides JSONB;
  v_cumpleanos JSONB;
  v_avisos JSONB;
  v_config JSONB;
BEGIN
  -- Efemérides del día
  SELECT jsonb_agg(
    jsonb_build_object(
      'id', e.id,
      'titulo', e.titulo,
      'descripcion', e.descripcion,
      'tipo', e.tipo,
      'icono', e.icono
    )
  )
  INTO v_efemerides
  FROM efemerides e
  WHERE e.dia = p_dia AND e.mes = p_mes AND e.estado = true;

  -- Cumpleaños del día (incluir globales con area_id NULL)
  SELECT jsonb_agg(
    jsonb_build_object(
      'id', c.id,
      'nombre', c.nombre,
      'cargo', c.cargo
    )
  )
  INTO v_cumpleanos
  FROM cumpleanos c
  WHERE c.dia = p_dia AND c.mes = p_mes AND c.estado = true
    AND (p_area_id IS NULL OR c.area_id IS NULL OR c.area_id = p_area_id);

  -- Avisos activos (con modo_display)
  SELECT jsonb_agg(
    jsonb_build_object(
      'id', a.id,
      'titulo', a.titulo,
      'mensaje', a.mensaje,
      'prioridad', a.prioridad,
      'modo_display', COALESCE(a.modo_display, 'periodico')
    ) ORDER BY
      CASE a.prioridad
        WHEN 'muy_importante' THEN 1
        WHEN 'importante' THEN 2
        ELSE 3
      END
  )
  INTO v_avisos
  FROM avisos a
  WHERE a.estado = true
    AND (p_area_id IS NULL OR a.area_id IS NULL OR a.area_id = p_area_id)
    AND a.fecha_inicio <= CURRENT_DATE
    AND (a.fecha_fin IS NULL OR a.fecha_fin >= CURRENT_DATE);

  -- Configuración TV
  SELECT jsonb_object_agg(c.clave, c.valor)
  INTO v_config
  FROM config_tv c;

  RETURN jsonb_build_object(
    'estado', 'success',
    'codigo', 200,
    'mensaje', jsonb_build_object(
      'efemerides', COALESCE(v_efemerides, '[]'::jsonb),
      'cumpleanos', COALESCE(v_cumpleanos, '[]'::jsonb),
      'avisos', COALESCE(v_avisos, '[]'::jsonb),
      'config', COALESCE(v_config, '{}'::jsonb)
    )
  );
END;
$$;
