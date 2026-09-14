-- =====================================================
-- MIGRACIÓN 37: Eliminar versión vieja de sp_asignar_usuario
-- =====================================================
-- Existe una versión con 5 parámetros (sin permisos) y otra con 6.
-- Eliminamos la vieja para evitar confusión.
-- =====================================================

-- Eliminar la versión vieja (5 parámetros, sin permisos)
DROP FUNCTION IF EXISTS public.sp_asignar_usuario(INT, INT, INT, TEXT, BOOL);

-- Verificar que solo queda la nueva versión
-- SELECT proname, pronargs FROM pg_proc WHERE proname = 'sp_asignar_usuario';
