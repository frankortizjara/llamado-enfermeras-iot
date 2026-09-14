-- ============================================
-- TABLAS: Efemérides, Cumpleaños y Avisos
-- ============================================

-- Tabla de Efemérides (fechas conmemorativas de salud)
CREATE TABLE IF NOT EXISTS efemerides (
  id SERIAL PRIMARY KEY,
  titulo VARCHAR(255) NOT NULL,
  descripcion TEXT,
  dia INTEGER NOT NULL CHECK (dia >= 1 AND dia <= 31),
  mes INTEGER NOT NULL CHECK (mes >= 1 AND mes <= 12),
  tipo VARCHAR(50) DEFAULT 'salud',
  icono VARCHAR(100),
  estado BOOLEAN DEFAULT true,
  fecha_registro TIMESTAMP DEFAULT NOW()
);

-- Tabla de Cumpleaños del personal
CREATE TABLE IF NOT EXISTS cumpleanos (
  id SERIAL PRIMARY KEY,
  nombre VARCHAR(255) NOT NULL,
  cargo VARCHAR(100),
  dia INTEGER NOT NULL CHECK (dia >= 1 AND dia <= 31),
  mes INTEGER NOT NULL CHECK (mes >= 1 AND mes <= 12),
  area_id INTEGER REFERENCES areas(id),
  estado BOOLEAN DEFAULT true,
  fecha_registro TIMESTAMP DEFAULT NOW()
);

-- Tabla de Avisos/Notas importantes
CREATE TABLE IF NOT EXISTS avisos (
  id SERIAL PRIMARY KEY,
  titulo VARCHAR(255) NOT NULL,
  mensaje TEXT NOT NULL,
  prioridad VARCHAR(20) DEFAULT 'normal' CHECK (prioridad IN ('normal', 'importante', 'muy_importante')),
  area_id INTEGER REFERENCES areas(id),
  creado_por INTEGER REFERENCES usuarios(id),
  fecha_inicio DATE DEFAULT CURRENT_DATE,
  fecha_fin DATE,
  estado BOOLEAN DEFAULT true,
  fecha_registro TIMESTAMP DEFAULT NOW()
);

-- ============================================
-- STORED PROCEDURES: Efemérides
-- ============================================

CREATE OR REPLACE FUNCTION sp_listar_efemerides()
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
  v_resultado JSONB;
BEGIN
  SELECT jsonb_agg(
    jsonb_build_object(
      'id', e.id,
      'titulo', e.titulo,
      'descripcion', e.descripcion,
      'dia', e.dia,
      'mes', e.mes,
      'tipo', e.tipo,
      'icono', e.icono,
      'estado', e.estado
    ) ORDER BY e.mes, e.dia
  )
  INTO v_resultado
  FROM efemerides e
  WHERE e.estado = true;

  RETURN jsonb_build_object(
    'estado', 'success',
    'codigo', 200,
    'mensaje', COALESCE(v_resultado, '[]'::jsonb)
  );
END;
$$;

CREATE OR REPLACE FUNCTION sp_obtener_efemerides_hoy(p_dia INTEGER, p_mes INTEGER)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
  v_resultado JSONB;
BEGIN
  SELECT jsonb_agg(
    jsonb_build_object(
      'id', e.id,
      'titulo', e.titulo,
      'descripcion', e.descripcion,
      'dia', e.dia,
      'mes', e.mes,
      'tipo', e.tipo,
      'icono', e.icono
    )
  )
  INTO v_resultado
  FROM efemerides e
  WHERE e.dia = p_dia AND e.mes = p_mes AND e.estado = true;

  RETURN jsonb_build_object(
    'estado', 'success',
    'codigo', 200,
    'mensaje', COALESCE(v_resultado, '[]'::jsonb)
  );
END;
$$;

CREATE OR REPLACE FUNCTION sp_agregar_efemeride(
  p_id INTEGER,
  p_titulo VARCHAR(255),
  p_descripcion TEXT,
  p_dia INTEGER,
  p_mes INTEGER,
  p_tipo VARCHAR(50),
  p_icono VARCHAR(100),
  p_estado BOOLEAN
)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
  v_id INTEGER;
BEGIN
  IF p_id IS NOT NULL AND p_id > 0 THEN
    UPDATE efemerides
    SET titulo = p_titulo, descripcion = p_descripcion,
        dia = p_dia, mes = p_mes, tipo = p_tipo,
        icono = p_icono, estado = p_estado
    WHERE id = p_id;
    v_id := p_id;
  ELSE
    INSERT INTO efemerides (titulo, descripcion, dia, mes, tipo, icono, estado)
    VALUES (p_titulo, p_descripcion, p_dia, p_mes, p_tipo, p_icono, COALESCE(p_estado, true))
    RETURNING id INTO v_id;
  END IF;

  RETURN jsonb_build_object(
    'estado', 'success',
    'codigo', 200,
    'mensaje', 'Efeméride guardada correctamente',
    'id', v_id
  );
END;
$$;

CREATE OR REPLACE FUNCTION sp_eliminar_efemeride(p_id INTEGER)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
BEGIN
  UPDATE efemerides SET estado = false WHERE id = p_id;

  RETURN jsonb_build_object(
    'estado', 'success',
    'codigo', 200,
    'mensaje', 'Efeméride eliminada correctamente'
  );
END;
$$;

-- ============================================
-- STORED PROCEDURES: Cumpleaños
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
    AND (p_area_id IS NULL OR c.area_id = p_area_id);

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
    AND (p_area_id IS NULL OR c.area_id = p_area_id);

  RETURN jsonb_build_object(
    'estado', 'success',
    'codigo', 200,
    'mensaje', COALESCE(v_resultado, '[]'::jsonb)
  );
END;
$$;

CREATE OR REPLACE FUNCTION sp_agregar_cumpleano(
  p_id INTEGER,
  p_nombre VARCHAR(255),
  p_cargo VARCHAR(100),
  p_dia INTEGER,
  p_mes INTEGER,
  p_area_id INTEGER,
  p_estado BOOLEAN
)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
  v_id INTEGER;
BEGIN
  IF p_id IS NOT NULL AND p_id > 0 THEN
    UPDATE cumpleanos
    SET nombre = p_nombre, cargo = p_cargo,
        dia = p_dia, mes = p_mes, area_id = p_area_id,
        estado = p_estado
    WHERE id = p_id;
    v_id := p_id;
  ELSE
    INSERT INTO cumpleanos (nombre, cargo, dia, mes, area_id, estado)
    VALUES (p_nombre, p_cargo, p_dia, p_mes, p_area_id, COALESCE(p_estado, true))
    RETURNING id INTO v_id;
  END IF;

  RETURN jsonb_build_object(
    'estado', 'success',
    'codigo', 200,
    'mensaje', 'Cumpleaños guardado correctamente',
    'id', v_id
  );
END;
$$;

CREATE OR REPLACE FUNCTION sp_eliminar_cumpleano(p_id INTEGER)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
BEGIN
  UPDATE cumpleanos SET estado = false WHERE id = p_id;

  RETURN jsonb_build_object(
    'estado', 'success',
    'codigo', 200,
    'mensaje', 'Cumpleaños eliminado correctamente'
  );
END;
$$;

-- ============================================
-- STORED PROCEDURES: Avisos
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

CREATE OR REPLACE FUNCTION sp_agregar_aviso(
  p_id INTEGER,
  p_titulo VARCHAR(255),
  p_mensaje TEXT,
  p_prioridad VARCHAR(20),
  p_area_id INTEGER,
  p_creado_por INTEGER,
  p_fecha_inicio DATE,
  p_fecha_fin DATE,
  p_estado BOOLEAN
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
        fecha_fin = p_fecha_fin, estado = p_estado
    WHERE id = p_id;
    v_id := p_id;
  ELSE
    INSERT INTO avisos (titulo, mensaje, prioridad, area_id, creado_por, fecha_inicio, fecha_fin, estado)
    VALUES (p_titulo, p_mensaje, COALESCE(p_prioridad, 'normal'), p_area_id, p_creado_por,
            COALESCE(p_fecha_inicio, CURRENT_DATE), p_fecha_fin, COALESCE(p_estado, true))
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

CREATE OR REPLACE FUNCTION sp_eliminar_aviso(p_id INTEGER)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
BEGIN
  UPDATE avisos SET estado = false WHERE id = p_id;

  RETURN jsonb_build_object(
    'estado', 'success',
    'codigo', 200,
    'mensaje', 'Aviso eliminado correctamente'
  );
END;
$$;

-- ============================================
-- STORED PROCEDURE: Contenido TV combinado
-- ============================================

CREATE OR REPLACE FUNCTION sp_obtener_contenido_tv(p_dia INTEGER, p_mes INTEGER, p_area_id INTEGER)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
  v_efemerides JSONB;
  v_cumpleanos JSONB;
  v_avisos JSONB;
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

  -- Cumpleaños del día
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
    AND (p_area_id IS NULL OR c.area_id = p_area_id);

  -- Avisos activos
  SELECT jsonb_agg(
    jsonb_build_object(
      'id', a.id,
      'titulo', a.titulo,
      'mensaje', a.mensaje,
      'prioridad', a.prioridad
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

  RETURN jsonb_build_object(
    'estado', 'success',
    'codigo', 200,
    'mensaje', jsonb_build_object(
      'efemerides', COALESCE(v_efemerides, '[]'::jsonb),
      'cumpleanos', COALESCE(v_cumpleanos, '[]'::jsonb),
      'avisos', COALESCE(v_avisos, '[]'::jsonb)
    )
  );
END;
$$;

-- ============================================
-- SEED DATA: Efemérides de Salud (Perú + Internacional)
-- ============================================

INSERT INTO efemerides (titulo, descripcion, dia, mes, tipo, icono) VALUES
-- ENERO
('Día Mundial de la Lucha contra la Depresión', 'Se busca concientizar sobre la depresión como enfermedad y promover su tratamiento oportuno.', 13, 1, 'internacional', 'bi bi-heart-pulse'),
('Día Mundial de la Lepra', 'Dedicado a crear conciencia sobre la lepra (enfermedad de Hansen) y reducir el estigma.', 31, 1, 'internacional', 'bi bi-bandaid'),

-- FEBRERO
('Día Mundial contra el Cáncer', 'Jornada de concientización global para prevenir y controlar el cáncer.', 4, 2, 'internacional', 'bi bi-shield-plus'),
('Día Internacional contra la Epilepsia', 'Purple Day: se promueve la concientización sobre la epilepsia en todo el mundo.', 14, 2, 'internacional', 'bi bi-lightning'),
('Día Internacional de las Enfermedades Raras', 'Se busca crear conciencia sobre las enfermedades raras y su impacto en los pacientes.', 28, 2, 'internacional', 'bi bi-search-heart'),

-- MARZO
('Día Mundial de la Audición', 'Promover la salud auditiva y prevenir la pérdida de audición.', 3, 3, 'internacional', 'bi bi-ear'),
('Día Internacional de la Mujer', 'Se reconoce el papel de la mujer en la salud y la sociedad.', 8, 3, 'internacional', 'bi bi-gender-female'),
('Día Mundial del Riñón', 'Concientización sobre la importancia de los riñones y la prevención de enfermedades renales.', 14, 3, 'internacional', 'bi bi-droplet-half'),
('Día Mundial de la Tuberculosis', 'Concientizar sobre la tuberculosis y los esfuerzos para eliminar esta enfermedad.', 24, 3, 'internacional', 'bi bi-lungs'),

-- ABRIL
('Día Mundial de la Salud', 'Celebrado por la OMS para promover la salud y el bienestar mundial.', 7, 4, 'internacional', 'bi bi-plus-circle'),
('Día Mundial de la Enfermedad de Chagas', 'Concientización sobre la enfermedad de Chagas y su prevención.', 14, 4, 'internacional', 'bi bi-bug'),
('Día Mundial del Paludismo (Malaria)', 'Esfuerzos mundiales para prevenir y tratar la malaria.', 25, 4, 'internacional', 'bi bi-thermometer-half'),
('Día de la Inmunización en las Américas', 'Promover la vacunación como herramienta clave de salud pública.', 26, 4, 'internacional', 'bi bi-shield-check'),

-- MAYO
('Día Mundial del Asma', 'Concientización sobre el asma y su manejo adecuado.', 7, 5, 'internacional', 'bi bi-wind'),
('Día Internacional de la Enfermera', 'Homenaje a las enfermeras y su labor fundamental en la salud.', 12, 5, 'internacional', 'bi bi-heart'),
('Día Mundial de la Hipertensión', 'Promover la prevención, detección y control de la hipertensión arterial.', 17, 5, 'internacional', 'bi bi-activity'),
('Día Mundial sin Tabaco', 'Promover la reducción del consumo de tabaco y sus efectos en la salud.', 31, 5, 'internacional', 'bi bi-slash-circle'),

-- JUNIO
('Día del Médico Peruano', 'Homenaje a todos los médicos peruanos por su dedicación y servicio.', 2, 6, 'peru', 'bi bi-hospital'),
('Día Mundial del Donante de Sangre', 'Agradecer a los donantes de sangre y fomentar las donaciones.', 14, 6, 'internacional', 'bi bi-droplet'),

-- JULIO
('Día Mundial de la Hepatitis', 'Concientización sobre las hepatitis virales y su prevención.', 28, 7, 'internacional', 'bi bi-clipboard2-pulse'),

-- AGOSTO
('Semana Mundial de la Lactancia Materna', 'Promover la lactancia materna para la salud del bebé y la madre.', 1, 8, 'internacional', 'bi bi-emoji-smile'),
('Día de la Enfermera Peruana', 'Homenaje a las enfermeras peruanas por su invaluable labor en la atención de salud.', 30, 8, 'peru', 'bi bi-heart-pulse-fill'),

-- SEPTIEMBRE
('Día Mundial de la Fisioterapia', 'Reconocer la labor de los fisioterapeutas en la recuperación de pacientes.', 8, 9, 'internacional', 'bi bi-person-walking'),
('Día Mundial del Alzheimer', 'Concientización sobre la enfermedad de Alzheimer y otras demencias.', 21, 9, 'internacional', 'bi bi-puzzle'),
('Día Mundial del Corazón', 'Promover la prevención de enfermedades cardiovasculares.', 29, 9, 'internacional', 'bi bi-heart-fill'),

-- OCTUBRE
('Día del Médico Peruano (EsSalud)', 'Celebración del Día del Médico en las instituciones de EsSalud.', 5, 10, 'peru', 'bi bi-hospital-fill'),
('Día Mundial de la Salud Mental', 'Promover la salud mental y crear conciencia sobre los trastornos mentales.', 10, 10, 'internacional', 'bi bi-emoji-heart-eyes'),
('Día Mundial de la Vista', 'Concientización sobre la ceguera y la discapacidad visual prevenible.', 12, 10, 'internacional', 'bi bi-eye'),
('Día Mundial contra el Cáncer de Mama', 'Concientización sobre la detección temprana del cáncer de mama.', 19, 10, 'internacional', 'bi bi-ribbon'),
('Día del Técnico en Enfermería Peruano', 'Reconocer la labor de los técnicos en enfermería del Perú.', 25, 10, 'peru', 'bi bi-person-badge'),

-- NOVIEMBRE
('Día Mundial de la Diabetes', 'Concientización sobre la diabetes y su prevención.', 14, 11, 'internacional', 'bi bi-droplet-fill'),
('Día Mundial de la EPOC', 'Concientización sobre la Enfermedad Pulmonar Obstructiva Crónica.', 15, 11, 'internacional', 'bi bi-lungs-fill'),
('Día del Pediatra Peruano', 'Homenaje a los pediatras peruanos por su dedicación a la salud infantil.', 20, 11, 'peru', 'bi bi-emoji-laughing'),
('Día Mundial de la Lucha contra el SIDA', 'Concientización sobre el VIH/SIDA y apoyo a las personas afectadas.', 1, 12, 'internacional', 'bi bi-ribbon-fill'),

-- DICIEMBRE
('Día de la Medicina Peruana', 'Celebrar la historia y los avances de la medicina en el Perú.', 5, 12, 'peru', 'bi bi-award'),
('Día Universal de la Salud', 'Reconocer el derecho a la salud como derecho humano fundamental.', 12, 12, 'internacional', 'bi bi-globe'),
('Día del Obstetra Peruano', 'Homenaje a los obstetras peruanos por su labor en la salud materna.', 24, 6, 'peru', 'bi bi-gender-female'),
('Día del Psicólogo Peruano', 'Reconocer la labor de los psicólogos en la salud mental del Perú.', 30, 4, 'peru', 'bi bi-chat-heart'),
('Día del Nutricionista Peruano', 'Homenaje a los nutricionistas peruanos por promover la alimentación saludable.', 6, 8, 'peru', 'bi bi-apple'),
('Día del Tecnólogo Médico Peruano', 'Reconocer la labor de los tecnólogos médicos del Perú.', 25, 9, 'peru', 'bi bi-microscope'),
('Día del Farmacéutico Peruano', 'Homenaje a los farmacéuticos peruanos por su rol en la salud pública.', 15, 4, 'peru', 'bi bi-capsule'),
('Día del Trabajador Social', 'Reconocer la labor del trabajador social en el ámbito de la salud.', 17, 3, 'peru', 'bi bi-people'),
('Día del Biólogo Peruano', 'Homenaje a los biólogos peruanos por su contribución a la ciencia y la salud.', 27, 11, 'peru', 'bi bi-tree'),
('Día Mundial del Lavado de Manos', 'Promover el lavado de manos como medida esencial de prevención.', 15, 10, 'internacional', 'bi bi-hand-thumbs-up'),
('Día de la Seguridad del Paciente', 'Promover la seguridad del paciente en los servicios de salud.', 17, 9, 'internacional', 'bi bi-shield-lock'),
('Día Internacional de las Personas con Discapacidad', 'Promover los derechos y el bienestar de las personas con discapacidad.', 3, 12, 'internacional', 'bi bi-universal-access'),
('Día Mundial de la Salud Sexual', 'Promover la salud sexual y los derechos sexuales.', 4, 9, 'internacional', 'bi bi-hearts'),
('Día del Odontólogo Peruano', 'Homenaje a los odontólogos peruanos por su labor en la salud bucal.', 4, 12, 'peru', 'bi bi-emoji-smile-fill'),
('Día Mundial de la Prevención del Suicidio', 'Concientización sobre la prevención del suicidio a nivel mundial.', 10, 9, 'internacional', 'bi bi-life-preserver')
ON CONFLICT DO NOTHING;
