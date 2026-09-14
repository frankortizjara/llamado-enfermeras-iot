-- =====================================================
-- MIGRACIÓN: Administración de usuarios
-- =====================================================
-- Agrega funciones para listar usuarios, cambiar clave,
-- y corrige sp_obtener_usuario para incluir el rol
-- =====================================================

-- Corregir sp_obtener_usuario para incluir el campo 'rol'
CREATE OR REPLACE FUNCTION public.sp_obtener_usuario(pi_usuario TEXT)
RETURNS JSONB AS $$
DECLARE
    resultado JSONB;
BEGIN
    BEGIN
        SELECT jsonb_build_object(
            'id', u.id, 'nombre', u.nombre, 'usuario', u.usuario, 'clave', u.clave,
            'area_id', au.area_id, 'area_nombre', ar.nombre, 'rol', au.rol, 'estado', u.estado
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

-- Función para listar todos los usuarios con sus asignaciones
CREATE OR REPLACE FUNCTION public.sp_listar_usuarios()
RETURNS JSONB AS $$
DECLARE
    resultado JSONB := '[]'::jsonb;
    registro RECORD;
BEGIN
    FOR registro IN
        SELECT u.id, u.nombre, u.usuario, u.estado,
               au.area_id, ar.nombre AS area_nombre, au.rol,
               u.fecha_registro, u.fecha_modificacion
        FROM public.usuarios u
        LEFT JOIN public.asignaciones_usuarios au ON u.id = au.usuario_id AND au.estado = true
        LEFT JOIN public.areas ar ON au.area_id = ar.id
        ORDER BY u.id
    LOOP
        resultado := resultado || jsonb_build_object(
            'id', registro.id,
            'nombre', registro.nombre,
            'usuario', registro.usuario,
            'estado', registro.estado,
            'area_id', registro.area_id,
            'area_nombre', registro.area_nombre,
            'rol', registro.rol,
            'fecha_registro', registro.fecha_registro
        );
    END LOOP;

    RETURN jsonb_build_object('estado', 'success', 'codigo', 200, 'mensaje', resultado);
EXCEPTION
    WHEN OTHERS THEN RETURN jsonb_build_object('estado', 'error', 'codigo', 500, 'mensaje', SQLERRM);
END;
$$ LANGUAGE plpgsql;

-- Función para cambiar clave de usuario
CREATE OR REPLACE FUNCTION public.sp_cambiar_clave(pi_id INT, pi_clave TEXT)
RETURNS JSONB AS $$
DECLARE
    resultado JSONB;
BEGIN
    BEGIN
        UPDATE public.usuarios SET clave = pi_clave, fecha_modificacion = CURRENT_TIMESTAMP WHERE id = pi_id;
        IF FOUND THEN
            resultado := jsonb_build_object('estado', 'success', 'codigo', 200, 'mensaje', 'Clave actualizada correctamente');
        ELSE
            resultado := jsonb_build_object('estado', 'error', 'codigo', 404, 'mensaje', 'Usuario no encontrado');
        END IF;
        RETURN resultado;
    EXCEPTION
        WHEN OTHERS THEN RETURN jsonb_build_object('estado', 'error', 'codigo', 500, 'mensaje', SQLERRM);
    END;
END;
$$ LANGUAGE plpgsql;
