-- ============================================
-- Índices para optimización de consultas
-- Sistema de Llamado de Enfermeras
-- ============================================

-- Índice para búsqueda de usuarios por nombre de usuario (login)
CREATE INDEX IF NOT EXISTS idx_usuarios_usuario
ON usuarios(usuario)
WHERE estado = true;

-- Índice para búsqueda de alertas por área y estado
CREATE INDEX IF NOT EXISTS idx_alertas_area_estado
ON alertas(area_id, estado_alerta);

-- Índice para búsqueda de alertas por dispositivo
CREATE INDEX IF NOT EXISTS idx_alertas_dispositivo
ON alertas(dispositivo_id);

-- Índice para búsqueda de alertas activas (no finalizadas)
CREATE INDEX IF NOT EXISTS idx_alertas_activas
ON alertas(area_id, fecha_registro)
WHERE estado_alerta = true;

-- Índice para búsqueda de camas EsSi por código
CREATE INDEX IF NOT EXISTS idx_camas_essi_codhab
ON camas_essi("codHabCama", estado);

-- Índice para búsqueda de camas EsSi activas
CREATE INDEX IF NOT EXISTS idx_camas_essi_activas
ON camas_essi("codHabCama")
WHERE estado = true;

-- Índice para búsqueda de asignaciones por usuario
CREATE INDEX IF NOT EXISTS idx_asignaciones_usuario
ON asignaciones_usuarios(usuario_id);

-- Índice para búsqueda de asignaciones por área
CREATE INDEX IF NOT EXISTS idx_asignaciones_area
ON asignaciones_usuarios(area_id);

-- Índice para búsqueda de habitaciones por área
CREATE INDEX IF NOT EXISTS idx_habitaciones_area
ON habitaciones(area_id)
WHERE estado = true;

-- Índice para búsqueda de camas por habitación
CREATE INDEX IF NOT EXISTS idx_camas_habitacion
ON camas(habitacion_id)
WHERE estado = true;

-- Índice para búsqueda de dispositivos ESP32 por serial
CREATE INDEX IF NOT EXISTS idx_dispositivos_serial
ON esp32_dispositivos(numero_serial)
WHERE estado = true;

-- Índice para búsqueda de dispositivos ESP32 por MAC
CREATE INDEX IF NOT EXISTS idx_dispositivos_mac
ON esp32_dispositivos(direccion_mac)
WHERE estado = true;

-- Índice compuesto para consulta de habitaciones con camas
CREATE INDEX IF NOT EXISTS idx_camas_habitacion_estado
ON camas(habitacion_id, estado);

-- Índice para ordenamiento de alertas por fecha
CREATE INDEX IF NOT EXISTS idx_alertas_fecha
ON alertas(fecha_registro DESC);

-- ============================================
-- Verificar índices creados
-- ============================================
-- SELECT indexname, tablename FROM pg_indexes
-- WHERE schemaname = 'public'
-- ORDER BY tablename, indexname;
