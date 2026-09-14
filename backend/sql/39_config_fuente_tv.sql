-- ============================================
-- ADD: Configuración de tamaño de fuente para TV
-- ============================================

INSERT INTO config_tv (clave, valor, descripcion) VALUES
  ('tamano_fuente_tv', '100', 'Tamaño de fuente en pantalla TV (porcentaje, 80-200)')
ON CONFLICT (clave) DO NOTHING;
