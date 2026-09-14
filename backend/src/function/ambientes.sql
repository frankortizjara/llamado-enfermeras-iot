---
CREATE OR REPLACE FUNCTION public.sp_agregar_area(
    pi_id INT,
    pi_cod_ses INT,
    pi_nombre TEXT,
    pi_estado BOOL
)
RETURNS JSONB AS $$
DECLARE
    resultado JSONB;
    nuevo_id INT;
    area_existe BOOLEAN;
BEGIN
    -- Iniciar transacción
    BEGIN
        IF pi_id = 0 THEN
            -- Insertar una nueva area
            INSERT INTO public.areas (cod_ses, nombre, estado, fecha_registro, fecha_modificacion)
            VALUES (pi_cod_ses, pi_nombre, pi_estado, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
            RETURNING id INTO nuevo_id;

            resultado := jsonb_build_object(
                'estado', 'success',
                'codigo', 201, -- 201 Created
                'mensaje', 'Area creada',
                'id', nuevo_id -- Devolver el ID del usuario creado
            );
        ELSE
            -- Actualizar usuario existente
            UPDATE public.areas
            SET cod_ses = pi_cod_ses,
                nombre = pi_nombre,
                estado = pi_estado,
                fecha_modificacion = CURRENT_TIMESTAMP
            WHERE id = pi_id;

            IF FOUND THEN
                resultado := jsonb_build_object(
                    'estado', 'success',
                    'codigo', 200, -- 200 OK
                    'mensaje', 'Area actualizada'
                );
            ELSE
                resultado := jsonb_build_object(
                    'estado', 'error',
                    'codigo', 404, -- 404 Not Found
                    'mensaje', 'Area no encontrada'
                );
            END IF;
        END IF;

        RETURN resultado;

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
CREATE OR REPLACE FUNCTION public.sp_agregar_habitacion(
    pi_id INT,
    pi_area_id INT,
    pi_nombre INT,
    pi_estado BOOL
)
RETURNS JSONB AS $$
DECLARE
    resultado JSONB;
    nuevo_id INT;
    habitacion_existe BOOLEAN;
BEGIN
    -- Iniciar transacción
    BEGIN
        IF pi_id = 0 THEN
            -- Insertar una nueva habitacion
            INSERT INTO public.habitaciones (area_id, nombre, estado, fecha_registro, fecha_modificacion)
            VALUES (pi_area_id, pi_nombre, pi_estado, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
            RETURNING id INTO nuevo_id;

            resultado := jsonb_build_object(
                'estado', 'success',
                'codigo', 201, -- 201 Created
                'mensaje', 'Habitacion creada',
                'id', nuevo_id -- Devolver el ID del usuario creado
            );
        ELSE
            -- Actualizar usuario existente
            UPDATE public.habitaciones
            SET area_id = pi_area_id,
                nombre = pi_nombre,
                estado = pi_estado,
                fecha_modificacion = CURRENT_TIMESTAMP
            WHERE id = pi_id;

            IF FOUND THEN
                resultado := jsonb_build_object(
                    'estado', 'success',
                    'codigo', 200, -- 200 OK
                    'mensaje', 'Habitacion actualizada'
                );
            ELSE
                resultado := jsonb_build_object(
                    'estado', 'error',
                    'codigo', 404, -- 404 Not Found
                    'mensaje', 'Habitacion no encontrada'
                );
            END IF;
        END IF;

        RETURN resultado;

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
CREATE OR REPLACE FUNCTION public.sp_agregar_cama(
    pi_id INT,
    pi_habitacion_id INT,
    pi_nombre TEXT,
    pi_paciente TEXT,
    pi_estado BOOL
)
RETURNS JSONB AS $$
DECLARE
    resultado JSONB;
    nuevo_id INT;
    cama_existe BOOLEAN;
BEGIN
    -- Iniciar transacción
    BEGIN
        IF pi_id = 0 THEN
            -- Insertar una nueva cama
            INSERT INTO public.camas (habitacion_id, nombre, paciente, estado, fecha_registro, fecha_modificacion)
            VALUES (pi_habitacion_id, pi_nombre, pi_paciente, pi_estado, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
            RETURNING id INTO nuevo_id;

            resultado := jsonb_build_object(
                'estado', 'success',
                'codigo', 201, -- 201 Created
                'mensaje', 'Cama creada',
                'id', nuevo_id -- Devolver el ID del usuario creado
            );
        ELSE
            -- Actualizar usuario existente
            UPDATE public.camas
            SET habitacion_id = pi_habitacion_id,
                nombre = pi_nombre,
				paciente = pi_paciente,
                estado = pi_estado,
                fecha_modificacion = CURRENT_TIMESTAMP
            WHERE id = pi_id;

            IF FOUND THEN
                resultado := jsonb_build_object(
                    'estado', 'success',
                    'codigo', 200, -- 200 OK
                    'mensaje', 'Cama actualizada'
                );
            ELSE
                resultado := jsonb_build_object(
                    'estado', 'error',
                    'codigo', 404, -- 404 Not Found
                    'mensaje', 'Cama no encontrada'
                );
            END IF;
        END IF;

        RETURN resultado;

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