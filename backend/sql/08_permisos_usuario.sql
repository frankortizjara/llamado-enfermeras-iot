-- =====================================================
-- MIGRACIÓN: Permisos granulares por usuario
-- =====================================================
-- Agrega columna 'permisos' JSONB a asignaciones_usuarios
-- y actualiza SPs para manejar permisos
-- =====================================================

-- 1. Agregar columna permisos
ALTER TABLE public.asignaciones_usuarios
ADD COLUMN IF NOT EXISTS permisos JSONB DEFAULT '{}'::jsonb;

-- 2. Actualizar sp_asignar_usuario para aceptar permisos
CREATE OR REPLACE FUNCTION public.sp_asignar_usuario(
    pi_id INT,
    pi_usuario_id INT,
    pi_area_id INT,
    pi_rol TEXT,
    pi_estado BOOL,
    pi_permisos JSONB DEFAULT '{}'::jsonb
)
RETURNS JSONB AS $$
DECLARE
    resultado JSONB;
    asignacion_existe BOOLEAN;
BEGIN
    BEGIN
        SELECT EXISTS(
            SELECT 1
            FROM public.asignaciones_usuarios
            WHERE usuario_id = pi_usuario_id
              AND area_id = pi_area_id
              AND id <> pi_id
        ) INTO asignacion_existe;

        IF asignacion_existe THEN
            RETURN jsonb_build_object(
                'estado', 'error',
                'codigo', 409,
                'mensaje', 'La asignación ya existe para el usuario en el área especificada'
            );
        END IF;

        IF pi_id = 0 THEN
            INSERT INTO public.asignaciones_usuarios (usuario_id, area_id, rol, estado, permisos, fecha_registro, fecha_modificacion)
            VALUES (pi_usuario_id, pi_area_id, pi_rol, pi_estado, pi_permisos, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
            RETURNING id INTO pi_id;

            resultado := jsonb_build_object(
                'estado', 'success',
                'codigo', 201,
                'mensaje', 'Asignación creada',
                'id', pi_id
            );
        ELSE
            UPDATE public.asignaciones_usuarios
            SET usuario_id = pi_usuario_id,
                area_id = pi_area_id,
                rol = pi_rol,
                estado = pi_estado,
                permisos = pi_permisos,
                fecha_modificacion = CURRENT_TIMESTAMP
            WHERE id = pi_id;

            IF FOUND THEN
                resultado := jsonb_build_object(
                    'estado', 'success',
                    'codigo', 200,
                    'mensaje', 'Asignación actualizada'
                );
            ELSE
                resultado := jsonb_build_object(
                    'estado', 'error',
                    'codigo', 404,
                    'mensaje', 'Asignación no encontrada'
                );
            END IF;
        END IF;

        RETURN resultado;

    EXCEPTION
        WHEN unique_violation THEN
            RETURN jsonb_build_object(
                'estado', 'error',
                'codigo', 409,
                'mensaje', 'La asignación ya existe para el usuario en el área especificada'
            );
        WHEN OTHERS THEN
            RETURN jsonb_build_object(
                'estado', 'error',
                'codigo', 500,
                'mensaje', SQLERRM
            );
    END;
END;
$$ LANGUAGE plpgsql;

-- 3. Actualizar sp_obtener_usuario para incluir permisos en el login
CREATE OR REPLACE FUNCTION public.sp_obtener_usuario(pi_usuario TEXT)
RETURNS JSONB AS $$
DECLARE
    resultado JSONB;
BEGIN
    BEGIN
        SELECT jsonb_build_object(
            'id', u.id, 'nombre', u.nombre, 'usuario', u.usuario, 'clave', u.clave,
            'area_id', au.area_id, 'area_nombre', ar.nombre, 'rol', au.rol,
            'permisos', COALESCE(au.permisos, '{}'::jsonb), 'estado', u.estado
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

-- 4. Actualizar sp_listar_usuarios para incluir permisos
CREATE OR REPLACE FUNCTION public.sp_listar_usuarios()
RETURNS JSONB AS $$
DECLARE
    resultado JSONB := '[]'::jsonb;
    registro RECORD;
BEGIN
    FOR registro IN
        SELECT u.id, u.nombre, u.usuario, u.estado,
               au.area_id, ar.nombre AS area_nombre, au.rol,
               COALESCE(au.permisos, '{}'::jsonb) AS permisos,
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
            'permisos', registro.permisos,
            'fecha_registro', registro.fecha_registro
        );
    END LOOP;

    RETURN jsonb_build_object('estado', 'success', 'codigo', 200, 'mensaje', resultado);
EXCEPTION
    WHEN OTHERS THEN RETURN jsonb_build_object('estado', 'error', 'codigo', 500, 'mensaje', SQLERRM);
END;
$$ LANGUAGE plpgsql;

-- 5. Asignar permisos completos al admin existente
UPDATE public.asignaciones_usuarios
SET permisos = '{
  "dispositivos": true,
  "analytics": true,
  "contenido_tv": true,
  "contenido_tv_efemerides": true,
  "contenido_tv_cumpleanos": true,
  "contenido_tv_avisos": true,
  "contenido_tv_audio": true,
  "contenido_tv_config": true,
  "usuarios": true
}'::jsonb
WHERE rol = 'admin';
