-- =====================================================
-- MIGRACION 21: Agregar campo 'rol' al SP de login
-- =====================================================
-- Modifica sp_obtener_usuario para incluir el rol del
-- usuario en la respuesta del login.
-- =====================================================

SET search_path TO public;

CREATE OR REPLACE FUNCTION public.sp_obtener_usuario(pi_usuario TEXT)
RETURNS JSONB AS $$
DECLARE
    resultado JSONB;
BEGIN
    BEGIN
        SELECT jsonb_build_object(
            'id', u.id,
            'nombre', u.nombre,
            'usuario', u.usuario,
            'clave', u.clave,
            'area_id', au.area_id,
            'area_nombre', ar.nombre,
            'rol', au.rol,
            'estado', u.estado
        ) INTO resultado
        FROM public.usuarios u
        LEFT JOIN public.asignaciones_usuarios au ON u.id = au.usuario_id
        LEFT JOIN public.areas ar ON au.area_id = ar.id
        WHERE u.usuario = pi_usuario;

        IF resultado IS NOT NULL THEN
            RETURN jsonb_build_object('estado', 'success', 'codigo', 200, 'mensaje', resultado);
        ELSE
            RETURN jsonb_build_object('estado', 'error', 'codigo', 404, 'mensaje', 'Usuario no encontrado');
        END IF;
    EXCEPTION
        WHEN OTHERS THEN RETURN jsonb_build_object('estado', 'error', 'codigo', 500, 'mensaje', SQLERRM);
    END;
END;
$$ LANGUAGE plpgsql;

-- Verificacion
DO $$
BEGIN
    RAISE NOTICE 'Migracion 21: sp_obtener_usuario actualizado con campo rol';
END $$;
