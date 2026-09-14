---
CREATE OR REPLACE FUNCTION public.sp_registrar_usuario(
    pi_id INT,
    pi_nombre TEXT,
    pi_usuario TEXT,
    pi_clave TEXT,
    pi_estado BOOL
)
RETURNS JSONB AS $$
DECLARE
    resultado JSONB;
    nuevo_id INT;
    usuario_existe BOOLEAN;
BEGIN
    -- Iniciar transacción
    BEGIN
        -- Verificar si el usuario ya existe
        SELECT EXISTS(
            SELECT 1
            FROM public.usuarios
            WHERE usuario = pi_usuario
            AND id <> pi_id
        ) INTO usuario_existe;

        IF usuario_existe THEN
            RETURN jsonb_build_object(
                'estado', 'error',
                'codigo', 409, -- 409 Conflict
                'mensaje', 'El nombre de usuario ya está en uso'
            );
        END IF;

        IF pi_id = 0 THEN
            -- Insertar un nuevo usuario
            INSERT INTO public.usuarios (nombre, usuario, clave, estado, fecha_registro, fecha_modificacion)
            VALUES (pi_nombre, pi_usuario, pi_clave, pi_estado, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
            RETURNING id INTO nuevo_id;

            resultado := jsonb_build_object(
                'estado', 'success',
                'codigo', 201, -- 201 Created
                'mensaje', 'Usuario creado',
                'id', nuevo_id -- Devolver el ID del usuario creado
            );
        ELSE
            -- Actualizar usuario existente
            UPDATE public.usuarios
            SET nombre = pi_nombre,
                usuario = pi_usuario,
                clave = pi_clave,
                estado = pi_estado,
                fecha_modificacion = CURRENT_TIMESTAMP
            WHERE id = pi_id;

            IF FOUND THEN
                resultado := jsonb_build_object(
                    'estado', 'success',
                    'codigo', 200, -- 200 OK
                    'mensaje', 'Usuario actualizado'
                );
            ELSE
                resultado := jsonb_build_object(
                    'estado', 'error',
                    'codigo', 404, -- 404 Not Found
                    'mensaje', 'Usuario no encontrado'
                );
            END IF;
        END IF;

        RETURN resultado;

    EXCEPTION
        WHEN unique_violation THEN
            RETURN jsonb_build_object(
                'estado', 'error',
                'codigo', 409, -- 409 Conflict
                'mensaje', 'El nombre de usuario ya está en uso'
            );
        WHEN OTHERS THEN
            RETURN jsonb_build_object(
                'estado', 'error',
                'codigo', 500, -- 500 Internal Server Error
                'mensaje', SQLERRM
            );
    END;
END;
$$ LANGUAGE plpgsql;

---

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
			'estado', u.estado
        ) INTO resultado
        FROM public.usuarios u
        LEFT JOIN public.asignaciones_usuarios au ON u.id = au.usuario_id
		LEFT JOIN public.areas ar ON au.area_id = ar.id
        WHERE u.usuario = pi_usuario;

        IF resultado IS NOT NULL THEN
            RETURN jsonb_build_object(
                'estado', 'success',
                'codigo', 200, -- 200 OK
                'mensaje', resultado
            );
        ELSE
            RETURN jsonb_build_object(
                'estado', 'error',
                'codigo', 404, -- 404 Not Found
                'mensaje', 'Usuario no encontrado'
            );
        END IF;

    EXCEPTION
        WHEN OTHERS THEN
            RETURN jsonb_build_object(
                'estado', 'error',
                'codigo', 500, -- 500 Internal Server Error
                'mensaje', SQLERRM
            );
    END;
END;
$$ LANGUAGE plpgsql;

---

CREATE OR REPLACE FUNCTION public.sp_eliminar_usuario(pi_id INT)
RETURNS JSONB AS $$
DECLARE
    resultado JSONB;
BEGIN
    BEGIN
        -- Intenta eliminar el usuario de la tabla
        DELETE FROM public.usuarios WHERE id = pi_id;
        
        -- Verifica si se eliminó al menos un usuario
        IF FOUND THEN
	        resultado := jsonb_build_object(
	            'estado', 'success',
	            'codigo', 200, -- 200 OK
	            'mensaje', 'Usuario borrado correctamente'
	        );
        ELSE
	        resultado := jsonb_build_object(
	            'estado', 'error',
	            'codigo', 404, -- 404 Not Found
	            'mensaje', 'Usuario no encontrado'
	        );
        END IF;
        
        RETURN resultado;

    EXCEPTION
        WHEN foreign_key_violation THEN
            RETURN jsonb_build_object(
                'estado', 'error',
                'codigo', 409, -- 409 Conflict
                'mensaje', 'No se puede eliminar el usuario debido a restricciones de integridad referencial'
            );
        WHEN OTHERS THEN
            RETURN jsonb_build_object(
                'estado', 'error',
                'codigo', 500, -- 500 Internal Server Error
                'mensaje', SQLERRM
            );
    END;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION public.sp_asignar_usuario(
    pi_id INT,
    pi_usuario_id INT,
    pi_area_id INT,
    pi_rol TEXT,
    pi_estado BOOL
)
RETURNS JSONB AS $$
DECLARE
    resultado JSONB;
    asignacion_existe BOOLEAN;
BEGIN
    -- Iniciar transacción
    BEGIN
        -- Verificar si la asignación ya existe
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
                'codigo', 409, -- 409 Conflict
                'mensaje', 'La asignación ya existe para el usuario en el área especificada'
            );
        END IF;

        IF pi_id = 0 THEN
            -- Insertar una nueva asignación
            INSERT INTO public.asignaciones_usuarios (usuario_id, area_id, rol, estado, fecha_registro, fecha_modificacion)
            VALUES (pi_usuario_id, pi_area_id, pi_rol, pi_estado, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
            RETURNING id INTO pi_id;

            resultado := jsonb_build_object(
                'estado', 'success',
                'codigo', 201, -- 201 Created
                'mensaje', 'Asignación creada',
                'id', pi_id -- Devolver el ID de la asignación creada
            );
        ELSE
            -- Actualizar asignación existente
            UPDATE public.asignaciones_usuarios
            SET usuario_id = pi_usuario_id,
                area_id = pi_area_id,
                rol = pi_rol,
                estado = pi_estado,
                fecha_modificacion = CURRENT_TIMESTAMP
            WHERE id = pi_id;

            IF FOUND THEN
                resultado := jsonb_build_object(
                    'estado', 'success',
                    'codigo', 200, -- 200 OK
                    'mensaje', 'Asignación actualizada'
                );
            ELSE
                resultado := jsonb_build_object(
                    'estado', 'error',
                    'codigo', 404, -- 404 Not Found
                    'mensaje', 'Asignación no encontrada'
                );
            END IF;
        END IF;

        RETURN resultado;

    EXCEPTION
        WHEN unique_violation THEN
            RETURN jsonb_build_object(
                'estado', 'error',
                'codigo', 409, -- 409 Conflict
                'mensaje', 'La asignación ya existe para el usuario en el área especificada'
            );
        WHEN OTHERS THEN
            RETURN jsonb_build_object(
                'estado', 'error',
                'codigo', 500, -- 500 Internal Server Error
                'mensaje', SQLERRM
            );
    END;
END;
$$ LANGUAGE plpgsql;

select * from public.sp_obtener_usuario('admin')
