-- ============================================
-- ADD: Configuración de audio para alertas TV
-- ============================================

INSERT INTO config_tv (clave, valor, descripcion) VALUES
  ('audio_habilitado', 'true', 'Habilitar o deshabilitar sonido de alertas en TV'),
  ('audio_volumen', '80', 'Volumen del audio (0-100)'),
  ('audio_duracion_alerta', '0', 'Duración en segundos del sonido de alerta normal (0 = continuo)'),
  ('audio_duracion_emergencia', '0', 'Duración en segundos del sonido de emergencia (0 = continuo)'),
  ('audio_sonido_alerta', 'Beep01.mp3', 'Archivo de sonido para alerta normal'),
  ('audio_sonido_emergencia', 'Beep02.mp3', 'Archivo de sonido para emergencia')
ON CONFLICT (clave) DO NOTHING;
