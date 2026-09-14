-- =====================================================
-- SISTEMA LLAMADO DE ENFERMERAS
-- Script COMPLETO de construccion de base de datos
-- =====================================================
-- Este script crea TODA la estructura desde cero:
--   - 13 tablas (incluye tablas de historial)
--   - Triggers de actualizacion automatica
--   - Todos los stored procedures (versiones finales)
--   - Indices de optimizacion
--   - NO inserta datos (los datos se cargan via CSV)
-- =====================================================
-- Ejecutar en una base de datos NUEVA y VACIA
-- =====================================================

SET search_path TO public;

-- =====================================================
-- PARTE 1: TABLAS PRINCIPALES
-- =====================================================

CREATE TABLE IF NOT EXISTS usuarios (
  id SERIAL PRIMARY KEY,
  nombre VARCHAR(255) NOT NULL,
  usuario VARCHAR(255) UNIQUE NOT NULL,
  clave VARCHAR(255) NOT NULL,
  estado BOOLEAN NOT NULL DEFAULT true,
  fecha_registro TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  fecha_modificacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS hospitales (
    hospital_id SERIAL PRIMARY KEY,
    cod_renaes INTEGER UNIQUE,
    cod_ses INTEGER UNIQUE,
    cod_eess INTEGER UNIQUE,
    tipo_ra1 VARCHAR(10),
    tipo VARCHAR(50),
    nombre VARCHAR(100),
    departamento VARCHAR(50),
    provincia VARCHAR(50),
    distrito VARCHAR(50),
    categoria VARCHAR(50),
    latitud DECIMAL(15, 12),
    longitud DECIMAL(15, 12),
    estado VARCHAR(50),
    enlace TEXT,
    fecha_registro TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    fecha_modificacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS areas (
  id SERIAL PRIMARY KEY,
  cod_ses INTEGER NOT NULL,
  nombre VARCHAR(255) NOT NULL,
  estado BOOLEAN NOT NULL DEFAULT true,
  fecha_registro TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  fecha_modificacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_hospitales_cod_ses FOREIGN KEY (cod_ses) REFERENCES hospitales (cod_ses)
);

CREATE TABLE IF NOT EXISTS habitaciones (
  id SERIAL PRIMARY KEY,
  area_id INTEGER NOT NULL,
  nombre INTEGER NOT NULL,
  estado BOOLEAN NOT NULL DEFAULT true,
  fecha_registro TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  fecha_modificacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_areas FOREIGN KEY (area_id) REFERENCES areas (id)
);

CREATE TABLE IF NOT EXISTS camas (
  id SERIAL PRIMARY KEY,
  habitacion_id INTEGER NOT NULL,
  nombre VARCHAR(255) NOT NULL,
  paciente VARCHAR(255),
  estado BOOLEAN NOT NULL DEFAULT true,
  fecha_registro TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  fecha_modificacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_habitaciones FOREIGN KEY (habitacion_id) REFERENCES habitaciones (id)
);

CREATE TABLE IF NOT EXISTS camas_essi (
  id SERIAL PRIMARY KEY,
  "codHabCama" VARCHAR(255) NOT NULL,
  "codHab" VARCHAR(255) NOT NULL,
  "codCama" VARCHAR(255) NOT NULL,
  "apeNomPac" VARCHAR(255) NOT NULL,
  "desEstCama" VARCHAR(255) NOT NULL,
  "desSerCama" VARCHAR(255) NOT NULL,
  "diashospi" VARCHAR(255) NOT NULL,
  "fechaIngreso" VARCHAR(255) NOT NULL,
  "nroDocIdePac" VARCHAR(255) NOT NULL,
  "nroHisCliCas" VARCHAR(255) NOT NULL,
  "tipoDocIdePac" VARCHAR(255) NOT NULL,
  nota VARCHAR(50) DEFAULT '',
  fecha_nota VARCHAR(255) DEFAULT '',
  estado BOOLEAN NOT NULL DEFAULT TRUE,
  fecha_registro TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  fecha_modificacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS esp32_dispositivos (
  id SERIAL PRIMARY KEY,
  numero_serial VARCHAR(12) UNIQUE NOT NULL,
  direccion_mac VARCHAR(17) UNIQUE NOT NULL,
  ip VARCHAR(45),
  estado BOOLEAN NOT NULL DEFAULT true,
  fecha_registro TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  fecha_modificacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS alertas (
  id SERIAL PRIMARY KEY,
  dispositivo_id INTEGER NOT NULL,
  area_id INTEGER NOT NULL,
  habitacion_id INTEGER NOT NULL,
  codigo_cama VARCHAR(50) NOT NULL,
  tipo_alerta INTEGER NOT NULL,
  estado_alerta BOOLEAN NOT NULL DEFAULT TRUE,
  tiempo_respuesta INTERVAL,
  fecha_registro TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  fecha_modificacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_esp32_dispositivos FOREIGN KEY (dispositivo_id) REFERENCES esp32_dispositivos (id),
  CONSTRAINT fk_areas_alertas FOREIGN KEY (area_id) REFERENCES areas (id)
);

CREATE TABLE IF NOT EXISTS asignaciones_usuarios (
  id SERIAL PRIMARY KEY,
  usuario_id INTEGER NOT NULL,
  area_id INTEGER NOT NULL,
  rol VARCHAR(50) NOT NULL,
  estado BOOLEAN NOT NULL DEFAULT true,
  fecha_asignacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  fecha_registro TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  fecha_modificacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_usuarios FOREIGN KEY (usuario_id) REFERENCES usuarios (id),
  CONSTRAINT fk_areas_asignaciones FOREIGN KEY (area_id) REFERENCES areas (id)
);

CREATE TABLE IF NOT EXISTS variables (
  id SERIAL PRIMARY KEY,
  nombre_variable VARCHAR(50) NOT NULL
);

-- =====================================================
-- PARTE 2: TABLAS DE HISTORIAL (AUDITORIA)
-- =====================================================

CREATE TABLE IF NOT EXISTS historial_notas (
    id SERIAL PRIMARY KEY,
    cama_essi_id INT NOT NULL,
    codhabcama VARCHAR(255),
    codhab VARCHAR(255),
    codcama VARCHAR(255),
    paciente VARCHAR(255),
    nota_anterior VARCHAR(50) DEFAULT '',
    nota_nueva VARCHAR(50) DEFAULT '',
    fecha_nota_anterior VARCHAR(255) DEFAULT '',
    fecha_nota_nueva VARCHAR(255) DEFAULT '',
    accion VARCHAR(20) NOT NULL,
    usuario_id INT,
    fecha_registro TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS historial_alertas (
    id SERIAL PRIMARY KEY,
    alerta_id INT NOT NULL,
    dispositivo_id INT,
    area_id INT,
    habitacion_id INT,
    codigo_cama VARCHAR(50),
    tipo_alerta INT,
    tiempo_respuesta INTERVAL,
    usuario_respuesta_id INT,
    fecha_alerta TIMESTAMP NOT NULL,
    fecha_respuesta TIMESTAMP NOT NULL,
    fecha_registro TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS historial_ocupacion (
    id SERIAL PRIMARY KEY,
    cama_essi_id INT,
    codhabcama VARCHAR(255),
    codhab VARCHAR(255),
    codcama VARCHAR(255),
    paciente VARCHAR(255),
    nrodocidepac VARCHAR(255),
    accion VARCHAR(20) NOT NULL,
    fecha_evento TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =====================================================
-- PARTE 3: TRIGGERS
-- =====================================================

CREATE OR REPLACE FUNCTION actualizar_fecha_modificacion()
RETURNS TRIGGER AS $$
BEGIN
    NEW.fecha_modificacion = CURRENT_TIMESTAMP;
    IF TG_TABLE_NAME = 'alertas' THEN
        NEW.tiempo_respuesta = NEW.fecha_modificacion - NEW.fecha_registro;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS tr_usuarios_update ON usuarios;
CREATE TRIGGER tr_usuarios_update BEFORE UPDATE ON usuarios FOR EACH ROW EXECUTE FUNCTION actualizar_fecha_modificacion();

DROP TRIGGER IF EXISTS tr_hospitales_update ON hospitales;
CREATE TRIGGER tr_hospitales_update BEFORE UPDATE ON hospitales FOR EACH ROW EXECUTE FUNCTION actualizar_fecha_modificacion();

DROP TRIGGER IF EXISTS tr_areas_update ON areas;
CREATE TRIGGER tr_areas_update BEFORE UPDATE ON areas FOR EACH ROW EXECUTE FUNCTION actualizar_fecha_modificacion();

DROP TRIGGER IF EXISTS tr_habitaciones_update ON habitaciones;
CREATE TRIGGER tr_habitaciones_update BEFORE UPDATE ON habitaciones FOR EACH ROW EXECUTE FUNCTION actualizar_fecha_modificacion();

DROP TRIGGER IF EXISTS tr_camas_update ON camas;
CREATE TRIGGER tr_camas_update BEFORE UPDATE ON camas FOR EACH ROW EXECUTE FUNCTION actualizar_fecha_modificacion();

DROP TRIGGER IF EXISTS tr_camas_essi_update ON camas_essi;
CREATE TRIGGER tr_camas_essi_update BEFORE UPDATE ON camas_essi FOR EACH ROW EXECUTE FUNCTION actualizar_fecha_modificacion();

DROP TRIGGER IF EXISTS tr_alertas_update ON alertas;
CREATE TRIGGER tr_alertas_update BEFORE UPDATE ON alertas FOR EACH ROW EXECUTE FUNCTION actualizar_fecha_modificacion();

DROP TRIGGER IF EXISTS tr_asignaciones_update ON asignaciones_usuarios;
CREATE TRIGGER tr_asignaciones_update BEFORE UPDATE ON asignaciones_usuarios FOR EACH ROW EXECUTE FUNCTION actualizar_fecha_modificacion();

-- =====================================================
-- PARTE 4: INDICES
-- =====================================================

CREATE INDEX IF NOT EXISTS idx_usuarios_usuario ON usuarios(usuario) WHERE estado = true;
CREATE INDEX IF NOT EXISTS idx_alertas_area_estado ON alertas(area_id, estado_alerta);
CREATE INDEX IF NOT EXISTS idx_alertas_dispositivo ON alertas(dispositivo_id);
CREATE INDEX IF NOT EXISTS idx_alertas_fecha ON alertas(fecha_registro DESC);
CREATE INDEX IF NOT EXISTS idx_camas_essi_codhab ON camas_essi("codHabCama", estado);
CREATE INDEX IF NOT EXISTS idx_camas_essi_activas ON camas_essi("codHabCama") WHERE estado = true;
CREATE INDEX IF NOT EXISTS idx_asignaciones_usuario ON asignaciones_usuarios(usuario_id);
CREATE INDEX IF NOT EXISTS idx_asignaciones_area ON asignaciones_usuarios(area_id);
CREATE INDEX IF NOT EXISTS idx_habitaciones_area ON habitaciones(area_id) WHERE estado = true;
CREATE INDEX IF NOT EXISTS idx_camas_habitacion ON camas(habitacion_id) WHERE estado = true;
CREATE INDEX IF NOT EXISTS idx_dispositivos_serial ON esp32_dispositivos(numero_serial) WHERE estado = true;
CREATE INDEX IF NOT EXISTS idx_dispositivos_mac ON esp32_dispositivos(direccion_mac) WHERE estado = true;
CREATE INDEX IF NOT EXISTS idx_historial_notas_cama ON historial_notas(cama_essi_id);
CREATE INDEX IF NOT EXISTS idx_historial_notas_fecha ON historial_notas(fecha_registro);
CREATE INDEX IF NOT EXISTS idx_historial_notas_usuario ON historial_notas(usuario_id);
CREATE INDEX IF NOT EXISTS idx_historial_alertas_area ON historial_alertas(area_id);
CREATE INDEX IF NOT EXISTS idx_historial_alertas_fecha ON historial_alertas(fecha_alerta);
CREATE INDEX IF NOT EXISTS idx_historial_alertas_habitacion ON historial_alertas(habitacion_id);
CREATE INDEX IF NOT EXISTS idx_historial_ocupacion_cama ON historial_ocupacion(codhab, codcama);
CREATE INDEX IF NOT EXISTS idx_historial_ocupacion_fecha ON historial_ocupacion(fecha_evento);
CREATE INDEX IF NOT EXISTS idx_historial_ocupacion_paciente ON historial_ocupacion(nrodocidepac);

-- =====================================================
-- PARTE 5: STORED PROCEDURES - USUARIOS
-- =====================================================

CREATE OR REPLACE FUNCTION public.sp_registrar_usuario(
    pi_id INT, pi_nombre TEXT, pi_usuario TEXT, pi_clave TEXT, pi_estado BOOL
)
RETURNS JSONB AS $$
DECLARE
    resultado JSONB;
    nuevo_id INT;
    usuario_existe BOOLEAN;
BEGIN
    BEGIN
        SELECT EXISTS(SELECT 1 FROM public.usuarios WHERE usuario = pi_usuario AND id <> pi_id) INTO usuario_existe;

        IF usuario_existe THEN
            RETURN jsonb_build_object('estado', 'error', 'codigo', 409, 'mensaje', 'El nombre de usuario ya está en uso');
        END IF;

        IF pi_id = 0 THEN
            INSERT INTO public.usuarios (nombre, usuario, clave, estado, fecha_registro, fecha_modificacion)
            VALUES (pi_nombre, pi_usuario, pi_clave, pi_estado, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
            RETURNING id INTO nuevo_id;
            resultado := jsonb_build_object('estado', 'success', 'codigo', 201, 'mensaje', 'Usuario creado', 'id', nuevo_id);
        ELSE
            UPDATE public.usuarios SET nombre = pi_nombre, usuario = pi_usuario, clave = pi_clave, estado = pi_estado, fecha_modificacion = CURRENT_TIMESTAMP WHERE id = pi_id;
            IF FOUND THEN
                resultado := jsonb_build_object('estado', 'success', 'codigo', 200, 'mensaje', 'Usuario actualizado');
            ELSE
                resultado := jsonb_build_object('estado', 'error', 'codigo', 404, 'mensaje', 'Usuario no encontrado');
            END IF;
        END IF;
        RETURN resultado;
    EXCEPTION
        WHEN unique_violation THEN RETURN jsonb_build_object('estado', 'error', 'codigo', 409, 'mensaje', 'El nombre de usuario ya está en uso');
        WHEN OTHERS THEN RETURN jsonb_build_object('estado', 'error', 'codigo', 500, 'mensaje', SQLERRM);
    END;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION public.sp_obtener_usuario(pi_usuario TEXT)
RETURNS JSONB AS $$
DECLARE
    resultado JSONB;
BEGIN
    BEGIN
        SELECT jsonb_build_object(
            'id', u.id, 'nombre', u.nombre, 'usuario', u.usuario, 'clave', u.clave,
            'area_id', au.area_id, 'area_nombre', ar.nombre, 'estado', u.estado
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

CREATE OR REPLACE FUNCTION public.sp_eliminar_usuario(pi_id INT)
RETURNS JSONB AS $$
DECLARE
    resultado JSONB;
BEGIN
    BEGIN
        DELETE FROM public.usuarios WHERE id = pi_id;
        IF FOUND THEN
            resultado := jsonb_build_object('estado', 'success', 'codigo', 200, 'mensaje', 'Usuario borrado correctamente');
        ELSE
            resultado := jsonb_build_object('estado', 'error', 'codigo', 404, 'mensaje', 'Usuario no encontrado');
        END IF;
        RETURN resultado;
    EXCEPTION
        WHEN foreign_key_violation THEN RETURN jsonb_build_object('estado', 'error', 'codigo', 409, 'mensaje', 'No se puede eliminar el usuario debido a restricciones de integridad');
        WHEN OTHERS THEN RETURN jsonb_build_object('estado', 'error', 'codigo', 500, 'mensaje', SQLERRM);
    END;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION public.sp_asignar_usuario(
    pi_id INT, pi_usuario_id INT, pi_area_id INT, pi_rol TEXT, pi_estado BOOL
)
RETURNS JSONB AS $$
DECLARE
    resultado JSONB;
    asignacion_existe BOOLEAN;
BEGIN
    BEGIN
        SELECT EXISTS(SELECT 1 FROM public.asignaciones_usuarios WHERE usuario_id = pi_usuario_id AND area_id = pi_area_id AND id <> pi_id) INTO asignacion_existe;

        IF asignacion_existe THEN
            RETURN jsonb_build_object('estado', 'error', 'codigo', 409, 'mensaje', 'La asignación ya existe');
        END IF;

        IF pi_id = 0 THEN
            INSERT INTO public.asignaciones_usuarios (usuario_id, area_id, rol, estado, fecha_registro, fecha_modificacion)
            VALUES (pi_usuario_id, pi_area_id, pi_rol, pi_estado, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
            RETURNING id INTO pi_id;
            resultado := jsonb_build_object('estado', 'success', 'codigo', 201, 'mensaje', 'Asignación creada', 'id', pi_id);
        ELSE
            UPDATE public.asignaciones_usuarios SET usuario_id = pi_usuario_id, area_id = pi_area_id, rol = pi_rol, estado = pi_estado, fecha_modificacion = CURRENT_TIMESTAMP WHERE id = pi_id;
            IF FOUND THEN
                resultado := jsonb_build_object('estado', 'success', 'codigo', 200, 'mensaje', 'Asignación actualizada');
            ELSE
                resultado := jsonb_build_object('estado', 'error', 'codigo', 404, 'mensaje', 'Asignación no encontrada');
            END IF;
        END IF;
        RETURN resultado;
    EXCEPTION
        WHEN OTHERS THEN RETURN jsonb_build_object('estado', 'error', 'codigo', 500, 'mensaje', SQLERRM);
    END;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- PARTE 6: STORED PROCEDURES - DISPOSITIVOS
-- =====================================================

CREATE OR REPLACE FUNCTION public.sp_agregar_esp32(
    pi_serial TEXT, pi_mac TEXT, pi_ip_wifi TEXT, pi_estado BOOL
)
RETURNS JSONB AS $$
DECLARE
    resultado JSONB;
    dispositivo_existe BOOLEAN;
    nuevo_id INT;
BEGIN
    SELECT EXISTS(SELECT 1 FROM public.esp32_dispositivos WHERE numero_serial = pi_serial OR direccion_mac = pi_mac) INTO dispositivo_existe;

    IF dispositivo_existe THEN
        UPDATE public.esp32_dispositivos SET estado = pi_estado, ip = pi_ip_wifi, fecha_modificacion = CURRENT_TIMESTAMP
        WHERE numero_serial = pi_serial OR direccion_mac = pi_mac;
        IF FOUND THEN
            resultado := jsonb_build_object('estado', 'success', 'codigo', 200, 'mensaje', 'Dispositivo actualizado');
        ELSE
            resultado := jsonb_build_object('estado', 'error', 'codigo', 404, 'mensaje', 'Dispositivo no encontrado');
        END IF;
    ELSE
        INSERT INTO public.esp32_dispositivos (numero_serial, direccion_mac, ip, estado, fecha_registro, fecha_modificacion)
        VALUES (pi_serial, pi_mac, pi_ip_wifi, pi_estado, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
        RETURNING id INTO nuevo_id;
        resultado := jsonb_build_object('estado', 'success', 'codigo', 201, 'mensaje', 'Dispositivo creado', 'id', nuevo_id);
    END IF;

    RETURN resultado;
EXCEPTION
    WHEN unique_violation THEN RETURN jsonb_build_object('estado', 'error', 'codigo', 409, 'mensaje', 'Dispositivo ya registrado');
    WHEN OTHERS THEN RETURN jsonb_build_object('estado', 'error', 'codigo', 500, 'mensaje', SQLERRM);
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- PARTE 7: STORED PROCEDURES - ALERTAS
-- (Version final con registro en historial_alertas)
-- =====================================================

CREATE OR REPLACE FUNCTION public.sp_agregar_registro(
    pi_numero_serial TEXT,
    pi_area_id INT,
    pi_habitacion_id INT,
    pi_codigo_cama TEXT,
    pi_tipo_alerta INT
)
RETURNS JSONB AS $$
DECLARE
    resultado JSONB;
    v_dispositivo_id INT;
    alerta RECORD;
    v_alertas_resueltas INT := 0;
BEGIN
    BEGIN
        SELECT id INTO v_dispositivo_id
        FROM public.esp32_dispositivos
        WHERE numero_serial = pi_numero_serial
        LIMIT 1;

        IF v_dispositivo_id IS NOT NULL THEN
            IF pi_tipo_alerta = 1 OR pi_tipo_alerta = 2 THEN
                FOR alerta IN
                    SELECT id FROM public.alertas
                    WHERE dispositivo_id = v_dispositivo_id
                    AND area_id = pi_area_id
                    AND habitacion_id = pi_habitacion_id
                    AND codigo_cama = pi_codigo_cama
                    AND tipo_alerta = pi_tipo_alerta
                    AND estado_alerta = TRUE
                LOOP
                    RETURN jsonb_build_object('estado', 'success', 'codigo', 409, 'mensaje', 'Registro aún sin atender');
                END LOOP;

                INSERT INTO public.alertas (
                    dispositivo_id, area_id, habitacion_id, codigo_cama,
                    tipo_alerta, estado_alerta, fecha_registro, fecha_modificacion
                ) VALUES (
                    v_dispositivo_id, pi_area_id, pi_habitacion_id, pi_codigo_cama,
                    pi_tipo_alerta, TRUE, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
                );
                RETURN jsonb_build_object('estado', 'success', 'codigo', 201, 'mensaje', 'Registro agregado correctamente');

            ELSIF pi_tipo_alerta = 3 THEN
                FOR alerta IN
                    SELECT id, dispositivo_id, area_id, habitacion_id,
                           codigo_cama, tipo_alerta, fecha_registro
                    FROM public.alertas
                    WHERE dispositivo_id = v_dispositivo_id
                    AND area_id = pi_area_id
                    AND habitacion_id = pi_habitacion_id
                    AND codigo_cama = pi_codigo_cama
                    AND estado_alerta = TRUE
                LOOP
                    UPDATE public.alertas
                    SET estado_alerta = FALSE, fecha_modificacion = CURRENT_TIMESTAMP
                    WHERE id = alerta.id;

                    INSERT INTO public.historial_alertas (
                        alerta_id, dispositivo_id, area_id, habitacion_id,
                        codigo_cama, tipo_alerta, tiempo_respuesta,
                        usuario_respuesta_id, fecha_alerta, fecha_respuesta
                    ) VALUES (
                        alerta.id, alerta.dispositivo_id, alerta.area_id,
                        alerta.habitacion_id, alerta.codigo_cama, alerta.tipo_alerta,
                        CURRENT_TIMESTAMP - alerta.fecha_registro,
                        NULL,
                        alerta.fecha_registro, CURRENT_TIMESTAMP
                    );

                    v_alertas_resueltas := v_alertas_resueltas + 1;
                END LOOP;

                IF v_alertas_resueltas > 0 THEN
                    RETURN jsonb_build_object('estado', 'success', 'codigo', 200, 'mensaje', 'Registros actualizados correctamente');
                ELSE
                    RETURN jsonb_build_object('estado', 'error', 'codigo', 404, 'mensaje', 'No hay registros por atender');
                END IF;
            END IF;
        ELSE
            RETURN jsonb_build_object('estado', 'error', 'codigo', 404, 'mensaje', 'Dispositivo no encontrado');
        END IF;
    EXCEPTION
        WHEN OTHERS THEN RETURN jsonb_build_object('estado', 'error', 'codigo', 500, 'mensaje', SQLERRM);
    END;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION public.sp_reconocer_alertas_habitacion(
    pi_habitacion_id INT,
    pi_usuario_id INT
)
RETURNS JSONB AS $$
DECLARE
    alerta RECORD;
    v_alertas_reconocidas INT := 0;
    v_tiempo_respuesta INTERVAL;
BEGIN
    BEGIN
        FOR alerta IN
            SELECT id, dispositivo_id, area_id, habitacion_id,
                   codigo_cama, tipo_alerta, fecha_registro
            FROM public.alertas
            WHERE habitacion_id = pi_habitacion_id
              AND estado_alerta = TRUE
        LOOP
            v_tiempo_respuesta := CURRENT_TIMESTAMP - alerta.fecha_registro;

            INSERT INTO public.historial_alertas (
                alerta_id, dispositivo_id, area_id, habitacion_id,
                codigo_cama, tipo_alerta, tiempo_respuesta,
                usuario_respuesta_id, fecha_alerta, fecha_respuesta
            ) VALUES (
                alerta.id, alerta.dispositivo_id, alerta.area_id,
                alerta.habitacion_id, alerta.codigo_cama, alerta.tipo_alerta,
                v_tiempo_respuesta, pi_usuario_id,
                alerta.fecha_registro, CURRENT_TIMESTAMP
            );

            UPDATE public.alertas
            SET estado_alerta = FALSE,
                tiempo_respuesta = v_tiempo_respuesta,
                fecha_modificacion = CURRENT_TIMESTAMP
            WHERE id = alerta.id;

            v_alertas_reconocidas := v_alertas_reconocidas + 1;
        END LOOP;

        IF v_alertas_reconocidas > 0 THEN
            RETURN jsonb_build_object('estado', 'success', 'codigo', 200, 'mensaje', format('%s alerta(s) reconocida(s)', v_alertas_reconocidas));
        ELSE
            RETURN jsonb_build_object('estado', 'error', 'codigo', 404, 'mensaje', 'No se encontraron alertas activas en esta habitacion');
        END IF;
    EXCEPTION
        WHEN OTHERS THEN RETURN jsonb_build_object('estado', 'error', 'codigo', 500, 'mensaje', SQLERRM);
    END;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- PARTE 8: STORED PROCEDURES - INFORMACION
-- (Versiones finales con registro en historial)
-- =====================================================

CREATE OR REPLACE FUNCTION public.sp_consultar_habitaciones(pi_id INT)
RETURNS JSONB AS $$
DECLARE
    usuario_existe BOOLEAN;
    habitaciones_json JSONB := '[]'::jsonb;
    camas_json JSONB;
    habitacion RECORD;
    cama RECORD;
BEGIN
    SELECT EXISTS(SELECT 1 FROM public.usuarios WHERE id = pi_id) INTO usuario_existe;

    IF usuario_existe THEN
        FOR habitacion IN
            SELECT h.id, h.nombre FROM habitaciones h
            JOIN asignaciones_usuarios au ON au.area_id = h.area_id
            WHERE au.usuario_id = pi_id AND h.estado = TRUE
        LOOP
            camas_json := '[]'::jsonb;
            FOR cama IN SELECT c.id, c.nombre, c.paciente FROM camas c WHERE c.habitacion_id = habitacion.id AND c.estado = TRUE LOOP
                camas_json := camas_json || jsonb_build_object('id', cama.id, 'nombre', cama.nombre, 'paciente', cama.paciente);
            END LOOP;
            habitaciones_json := habitaciones_json || jsonb_build_object('id', habitacion.id, 'nombre', habitacion.nombre, 'camas', camas_json);
        END LOOP;
        RETURN jsonb_build_object('estado', 'success', 'codigo', 200, 'mensaje', habitaciones_json);
    ELSE
        RETURN jsonb_build_object('estado', 'error', 'codigo', 404, 'mensaje', 'Usuario no encontrado');
    END IF;
EXCEPTION
    WHEN OTHERS THEN RETURN jsonb_build_object('estado', 'error', 'codigo', 500, 'mensaje', SQLERRM);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION public.sp_consultar_habitaciones_essi(codHabCama_input VARCHAR)
RETURNS JSONB AS $$
DECLARE
    habitaciones_json JSONB := '[]'::jsonb;
    camas_json JSONB;
    habitacion RECORD;
    cama RECORD;
    ultima_sync TIMESTAMP;
BEGIN
    -- Obtener fecha de ultima sincronizacion (usa fecha_modificacion para reflejar updates del cron)
    SELECT MAX(fecha_modificacion) INTO ultima_sync
    FROM public.camas_essi
    WHERE "codHabCama" = codHabCama_input
    AND estado = TRUE;

    FOR habitacion IN SELECT "codHab" FROM camas_essi WHERE "codHabCama" = codHabCama_input GROUP BY "codHab" ORDER BY "codHab" LOOP
        camas_json := '[]'::jsonb;
        FOR cama IN
            SELECT id, "codCama", "nroDocIdePac", "nroHisCliCas", "tipoDocIdePac", "apeNomPac", nota, fecha_nota
            FROM camas_essi c WHERE c."codHab" = habitacion."codHab" AND c."codHabCama" = codHabCama_input AND c.estado = TRUE
            ORDER BY "codCama"
        LOOP
            camas_json := camas_json || jsonb_build_object('id', cama.id, 'nombre', cama."codCama", 'paciente', cama."apeNomPac", 'nota', cama.nota, 'fecha_nota', cama.fecha_nota);
        END LOOP;
        habitaciones_json := habitaciones_json || jsonb_build_object('nombre', habitacion."codHab", 'camas', camas_json);
    END LOOP;

    RETURN jsonb_build_object(
        'estado', 'success',
        'codigo', 200,
        'mensaje', jsonb_build_object(
            'habitaciones', habitaciones_json,
            'ultimaSincronizacion', COALESCE(TO_CHAR(ultima_sync, 'DD/MM/YYYY HH12:MI AM'), 'Sin datos')
        )
    );
EXCEPTION
    WHEN OTHERS THEN RETURN jsonb_build_object('estado', 'error', 'codigo', 500, 'mensaje', SQLERRM);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION public.sp_consultar_alertas(pi_area_id INT)
RETURNS JSONB AS $$
DECLARE
    habitaciones_json JSONB := '[]'::jsonb;
    camas_json JSONB;
    habitacion RECORD;
    cama RECORD;
    tipo_alerta_habitacion INT := 0;
BEGIN
    FOR habitacion IN SELECT DISTINCT a.habitacion_id FROM alertas a WHERE a.area_id = pi_area_id AND a.estado_alerta = TRUE ORDER BY a.habitacion_id LOOP
        camas_json := '[]'::jsonb;
        tipo_alerta_habitacion := 1;

        FOR cama IN SELECT a.id, a.codigo_cama, a.tipo_alerta FROM alertas a WHERE a.habitacion_id = habitacion.habitacion_id AND a.estado_alerta = TRUE LOOP
            IF cama.tipo_alerta = 2 THEN tipo_alerta_habitacion := 2; END IF;
            camas_json := camas_json || jsonb_build_object('id', cama.id, 'nombre', cama.codigo_cama);
        END LOOP;

        habitaciones_json := habitaciones_json || jsonb_build_object('nombre', habitacion.habitacion_id, 'estado', tipo_alerta_habitacion, 'camas', camas_json);
    END LOOP;

    RETURN jsonb_build_object('estado', 'success', 'codigo', 200, 'mensaje', habitaciones_json);
EXCEPTION
    WHEN OTHERS THEN RETURN jsonb_build_object('estado', 'error', 'codigo', 500, 'mensaje', SQLERRM);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION public.sp_consultar_info_habitaciones()
RETURNS JSONB AS $$
DECLARE
    resultado JSONB := '[]'::jsonb;
    registro RECORD;
BEGIN
    FOR registro IN
        SELECT "apeNomPac", "codHab" || "codCama" AS "codCama", "codHabCama", "desEstCama", "desSerCama",
               "diashospi", "fechaIngreso", "nroDocIdePac", "nroHisCliCas", "tipoDocIdePac"
        FROM camas_essi WHERE estado = TRUE
    LOOP
        resultado := resultado || jsonb_build_object(
            'apeNomPac', registro."apeNomPac", 'codCama', registro."codCama", 'codHabCama', registro."codHabCama",
            'desEstCama', registro."desEstCama", 'desSerCama', registro."desSerCama", 'diashospi', registro."diashospi",
            'fechaIngreso', registro."fechaIngreso", 'nroDocIdePac', registro."nroDocIdePac",
            'nroHisCliCas', registro."nroHisCliCas", 'tipoDocIdePac', registro."tipoDocIdePac"
        );
    END LOOP;
    RETURN jsonb_build_object('estado', 'success', 'codigo', 200, 'mensaje', resultado);
EXCEPTION
    WHEN OTHERS THEN RETURN jsonb_build_object('estado', 'error', 'codigo', 500, 'mensaje', SQLERRM);
END;
$$ LANGUAGE plpgsql;

-- sp_editar_nota: Version final con historial de notas
CREATE OR REPLACE FUNCTION public.sp_editar_nota(
    pi_id INT,
    pi_nota TEXT,
    pi_fecha_nota TEXT,
    pi_usuario_id INT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_nota_anterior VARCHAR(50);
    v_fecha_nota_anterior VARCHAR(255);
    v_codhabcama VARCHAR(255);
    v_codhab VARCHAR(255);
    v_codcama VARCHAR(255);
    v_paciente VARCHAR(255);
    v_accion VARCHAR(20);
BEGIN
    SELECT nota, fecha_nota, "codHabCama", "codHab", "codCama", "apeNomPac"
    INTO v_nota_anterior, v_fecha_nota_anterior, v_codhabcama, v_codhab, v_codcama, v_paciente
    FROM public.camas_essi
    WHERE id = pi_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('estado', 'error', 'codigo', 404, 'mensaje', 'Cama no encontrada');
    END IF;

    IF COALESCE(v_nota_anterior, '') = '' AND COALESCE(pi_nota, '') != '' THEN
        v_accion := 'CREAR';
    ELSIF COALESCE(v_nota_anterior, '') != '' AND COALESCE(pi_nota, '') = '' THEN
        v_accion := 'ELIMINAR';
    ELSE
        v_accion := 'MODIFICAR';
    END IF;

    INSERT INTO public.historial_notas (
        cama_essi_id, codhabcama, codhab, codcama, paciente,
        nota_anterior, nota_nueva,
        fecha_nota_anterior, fecha_nota_nueva,
        accion, usuario_id
    ) VALUES (
        pi_id, v_codhabcama, v_codhab, v_codcama, v_paciente,
        COALESCE(v_nota_anterior, ''), COALESCE(pi_nota, ''),
        COALESCE(v_fecha_nota_anterior, ''), COALESCE(pi_fecha_nota, ''),
        v_accion, pi_usuario_id
    );

    UPDATE public.camas_essi
    SET nota = pi_nota, fecha_nota = pi_fecha_nota, fecha_modificacion = CURRENT_TIMESTAMP
    WHERE id = pi_id;

    RETURN jsonb_build_object('estado', 'success', 'codigo', 200, 'mensaje', 'Nota actualizada');
EXCEPTION
    WHEN OTHERS THEN RETURN jsonb_build_object('estado', 'error', 'codigo', 500, 'mensaje', SQLERRM);
END;
$$ LANGUAGE plpgsql;

-- sp_cargar_data_essi: Version final con historial de ocupacion
CREATE OR REPLACE FUNCTION public.sp_cargar_data_essi(
    p_apenompac VARCHAR,
    p_codhabcama VARCHAR,
    p_codhab VARCHAR,
    p_codcama VARCHAR,
    p_desestcama VARCHAR,
    p_dessercama VARCHAR,
    p_diashospi VARCHAR,
    p_fechaingreso VARCHAR,
    p_nrodocidepac VARCHAR,
    p_nrohisclicas VARCHAR,
    p_tipodocidepac VARCHAR
)
RETURNS JSONB AS $$
DECLARE
    v_existing_id INT;
    v_existing_paciente VARCHAR;
    v_existing_nombre VARCHAR;
    v_new_id INT;
BEGIN
    SELECT id, "nroDocIdePac", "apeNomPac"
    INTO v_existing_id, v_existing_paciente, v_existing_nombre
    FROM public.camas_essi
    WHERE "codHabCama" = p_codhabcama
      AND "codHab" = p_codhab
      AND "codCama" = p_codcama
      AND estado = TRUE
    LIMIT 1;

    IF v_existing_id IS NOT NULL THEN
        IF v_existing_paciente = p_nrodocidepac THEN
            UPDATE public.camas_essi
            SET "apeNomPac" = p_apenompac,
                "desEstCama" = p_desestcama,
                "desSerCama" = p_dessercama,
                "diashospi" = p_diashospi,
                "fechaIngreso" = p_fechaingreso,
                "nroHisCliCas" = p_nrohisclicas,
                "tipoDocIdePac" = p_tipodocidepac,
                fecha_modificacion = CURRENT_TIMESTAMP
            WHERE id = v_existing_id;

            RETURN jsonb_build_object('estado', 'success', 'codigo', 200, 'mensaje', 'Registro actualizado');
        ELSE
            IF COALESCE(v_existing_nombre, '') != '' THEN
                INSERT INTO public.historial_ocupacion (
                    cama_essi_id, codhabcama, codhab, codcama,
                    paciente, nrodocidepac, accion
                ) VALUES (
                    v_existing_id, p_codhabcama, p_codhab, p_codcama,
                    v_existing_nombre, v_existing_paciente, 'EGRESO'
                );
            END IF;

            UPDATE public.camas_essi
            SET estado = FALSE, fecha_modificacion = CURRENT_TIMESTAMP
            WHERE id = v_existing_id;

            INSERT INTO public.camas_essi (
                "codHabCama", "codHab", "codCama", "apeNomPac",
                "desEstCama", "desSerCama", "diashospi", "fechaIngreso",
                "nroDocIdePac", "nroHisCliCas", "tipoDocIdePac",
                estado, fecha_registro, fecha_modificacion
            ) VALUES (
                p_codhabcama, p_codhab, p_codcama, p_apenompac,
                p_desestcama, p_dessercama, p_diashospi, p_fechaingreso,
                p_nrodocidepac, p_nrohisclicas, p_tipodocidepac,
                TRUE, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
            ) RETURNING id INTO v_new_id;

            IF COALESCE(p_apenompac, '') != '' THEN
                INSERT INTO public.historial_ocupacion (
                    cama_essi_id, codhabcama, codhab, codcama,
                    paciente, nrodocidepac, accion
                ) VALUES (
                    v_new_id, p_codhabcama, p_codhab, p_codcama,
                    p_apenompac, p_nrodocidepac, 'INGRESO'
                );
            END IF;

            RETURN jsonb_build_object('estado', 'success', 'codigo', 200, 'mensaje', 'Paciente cambiado en cama');
        END IF;
    ELSE
        INSERT INTO public.camas_essi (
            "codHabCama", "codHab", "codCama", "apeNomPac",
            "desEstCama", "desSerCama", "diashospi", "fechaIngreso",
            "nroDocIdePac", "nroHisCliCas", "tipoDocIdePac",
            estado, fecha_registro, fecha_modificacion
        ) VALUES (
            p_codhabcama, p_codhab, p_codcama, p_apenompac,
            p_desestcama, p_dessercama, p_diashospi, p_fechaingreso,
            p_nrodocidepac, p_nrohisclicas, p_tipodocidepac,
            TRUE, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
        ) RETURNING id INTO v_new_id;

        IF COALESCE(p_apenompac, '') != '' THEN
            INSERT INTO public.historial_ocupacion (
                cama_essi_id, codhabcama, codhab, codcama,
                paciente, nrodocidepac, accion
            ) VALUES (
                v_new_id, p_codhabcama, p_codhab, p_codcama,
                p_apenompac, p_nrodocidepac, 'INGRESO'
            );
        END IF;

        RETURN jsonb_build_object('estado', 'success', 'codigo', 200, 'mensaje', 'Registro insertado exitosamente');
    END IF;

EXCEPTION
    WHEN unique_violation THEN
        PERFORM setval('camas_essi_id_seq', (SELECT MAX(id) FROM camas_essi));
        UPDATE public.camas_essi
        SET "apeNomPac" = p_apenompac, "desEstCama" = p_desestcama,
            "desSerCama" = p_dessercama, "diashospi" = p_diashospi,
            "fechaIngreso" = p_fechaingreso, "nroDocIdePac" = p_nrodocidepac,
            "nroHisCliCas" = p_nrohisclicas, "tipoDocIdePac" = p_tipodocidepac,
            estado = TRUE, fecha_modificacion = CURRENT_TIMESTAMP
        WHERE "codHabCama" = p_codhabcama AND "codHab" = p_codhab
          AND "codCama" = p_codcama AND estado = TRUE;
        IF FOUND THEN
            RETURN jsonb_build_object('estado', 'success', 'codigo', 200, 'mensaje', 'Registro actualizado (secuencia corregida)');
        ELSE
            RETURN jsonb_build_object('estado', 'error', 'codigo', 500, 'mensaje', 'Error de secuencia: no se pudo recuperar');
        END IF;
    WHEN OTHERS THEN
        RETURN jsonb_build_object('estado', 'error', 'codigo', 500, 'mensaje', SQLERRM);
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- PARTE 9: STORED PROCEDURES - AMBIENTES
-- =====================================================

CREATE OR REPLACE FUNCTION public.sp_agregar_area(pi_id INT, pi_cod_ses INT, pi_nombre TEXT, pi_estado BOOL)
RETURNS JSONB AS $$
DECLARE
    resultado JSONB;
    nuevo_id INT;
BEGIN
    BEGIN
        IF pi_id = 0 THEN
            INSERT INTO public.areas (cod_ses, nombre, estado, fecha_registro, fecha_modificacion)
            VALUES (pi_cod_ses, pi_nombre, pi_estado, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
            RETURNING id INTO nuevo_id;
            resultado := jsonb_build_object('estado', 'success', 'codigo', 201, 'mensaje', 'Area creada', 'id', nuevo_id);
        ELSE
            UPDATE public.areas SET cod_ses = pi_cod_ses, nombre = pi_nombre, estado = pi_estado, fecha_modificacion = CURRENT_TIMESTAMP WHERE id = pi_id;
            IF FOUND THEN
                resultado := jsonb_build_object('estado', 'success', 'codigo', 200, 'mensaje', 'Area actualizada');
            ELSE
                resultado := jsonb_build_object('estado', 'error', 'codigo', 404, 'mensaje', 'Area no encontrada');
            END IF;
        END IF;
        RETURN resultado;
    EXCEPTION
        WHEN OTHERS THEN RETURN jsonb_build_object('estado', 'error', 'codigo', 500, 'mensaje', SQLERRM);
    END;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION public.sp_agregar_habitacion(pi_id INT, pi_area_id INT, pi_nombre INT, pi_estado BOOL)
RETURNS JSONB AS $$
DECLARE
    resultado JSONB;
    nuevo_id INT;
BEGIN
    BEGIN
        IF pi_id = 0 THEN
            INSERT INTO public.habitaciones (area_id, nombre, estado, fecha_registro, fecha_modificacion)
            VALUES (pi_area_id, pi_nombre, pi_estado, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
            RETURNING id INTO nuevo_id;
            resultado := jsonb_build_object('estado', 'success', 'codigo', 201, 'mensaje', 'Habitacion creada', 'id', nuevo_id);
        ELSE
            UPDATE public.habitaciones SET area_id = pi_area_id, nombre = pi_nombre, estado = pi_estado, fecha_modificacion = CURRENT_TIMESTAMP WHERE id = pi_id;
            IF FOUND THEN
                resultado := jsonb_build_object('estado', 'success', 'codigo', 200, 'mensaje', 'Habitacion actualizada');
            ELSE
                resultado := jsonb_build_object('estado', 'error', 'codigo', 404, 'mensaje', 'Habitacion no encontrada');
            END IF;
        END IF;
        RETURN resultado;
    EXCEPTION
        WHEN OTHERS THEN RETURN jsonb_build_object('estado', 'error', 'codigo', 500, 'mensaje', SQLERRM);
    END;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION public.sp_agregar_cama(pi_id INT, pi_habitacion_id INT, pi_nombre TEXT, pi_paciente TEXT, pi_estado BOOL)
RETURNS JSONB AS $$
DECLARE
    resultado JSONB;
    nuevo_id INT;
BEGIN
    BEGIN
        IF pi_id = 0 THEN
            INSERT INTO public.camas (habitacion_id, nombre, paciente, estado, fecha_registro, fecha_modificacion)
            VALUES (pi_habitacion_id, pi_nombre, pi_paciente, pi_estado, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
            RETURNING id INTO nuevo_id;
            resultado := jsonb_build_object('estado', 'success', 'codigo', 201, 'mensaje', 'Cama creada', 'id', nuevo_id);
        ELSE
            UPDATE public.camas SET habitacion_id = pi_habitacion_id, nombre = pi_nombre, paciente = pi_paciente, estado = pi_estado, fecha_modificacion = CURRENT_TIMESTAMP WHERE id = pi_id;
            IF FOUND THEN
                resultado := jsonb_build_object('estado', 'success', 'codigo', 200, 'mensaje', 'Cama actualizada');
            ELSE
                resultado := jsonb_build_object('estado', 'error', 'codigo', 404, 'mensaje', 'Cama no encontrada');
            END IF;
        END IF;
        RETURN resultado;
    EXCEPTION
        WHEN OTHERS THEN RETURN jsonb_build_object('estado', 'error', 'codigo', 500, 'mensaje', SQLERRM);
    END;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- PARTE 10: STORED PROCEDURES - ANALYTICS
-- =====================================================

CREATE OR REPLACE FUNCTION public.sp_analytics_tiempos_respuesta(
    pi_area_id INT, pi_fecha_inicio TIMESTAMP, pi_fecha_fin TIMESTAMP
)
RETURNS JSONB AS $$
DECLARE
    resultado JSONB;
    por_habitacion JSONB;
BEGIN
    BEGIN
        SELECT jsonb_build_object(
            'tiempo_promedio_minutos', COALESCE(ROUND(EXTRACT(EPOCH FROM AVG(tiempo_respuesta)) / 60, 2), 0),
            'tiempo_minimo_minutos', COALESCE(ROUND(EXTRACT(EPOCH FROM MIN(tiempo_respuesta)) / 60, 2), 0),
            'tiempo_maximo_minutos', COALESCE(ROUND(EXTRACT(EPOCH FROM MAX(tiempo_respuesta)) / 60, 2), 0),
            'total_alertas', COUNT(*)
        ) INTO resultado
        FROM public.historial_alertas
        WHERE area_id = pi_area_id AND fecha_alerta BETWEEN pi_fecha_inicio AND pi_fecha_fin;

        SELECT COALESCE(jsonb_agg(row_data), '[]'::jsonb) INTO por_habitacion
        FROM (
            SELECT jsonb_build_object(
                'habitacion_id', habitacion_id,
                'tiempo_promedio_minutos', ROUND(EXTRACT(EPOCH FROM AVG(tiempo_respuesta)) / 60, 2),
                'total_alertas', COUNT(*),
                'con_usuario', COUNT(usuario_respuesta_id),
                'sin_usuario', COUNT(*) - COUNT(usuario_respuesta_id)
            ) AS row_data
            FROM public.historial_alertas
            WHERE area_id = pi_area_id AND fecha_alerta BETWEEN pi_fecha_inicio AND pi_fecha_fin
            GROUP BY habitacion_id ORDER BY habitacion_id
        ) sub;

        resultado := resultado || jsonb_build_object('por_habitacion', por_habitacion);
        RETURN jsonb_build_object('estado', 'success', 'codigo', 200, 'mensaje', resultado);
    EXCEPTION
        WHEN OTHERS THEN RETURN jsonb_build_object('estado', 'error', 'codigo', 500, 'mensaje', SQLERRM);
    END;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION public.sp_analytics_historial_notas(
    pi_area_id INT, pi_fecha_inicio TIMESTAMP, pi_fecha_fin TIMESTAMP
)
RETURNS JSONB AS $$
DECLARE
    resultado JSONB;
    por_accion JSONB;
    por_usuario JSONB;
    v_area_nombre VARCHAR(255);
BEGIN
    BEGIN
        SELECT nombre INTO v_area_nombre FROM public.areas WHERE id = pi_area_id;

        SELECT COALESCE(jsonb_agg(row_data), '[]'::jsonb) INTO por_accion
        FROM (
            SELECT jsonb_build_object('accion', accion, 'total', COUNT(*)) AS row_data
            FROM public.historial_notas
            WHERE codhabcama = v_area_nombre AND fecha_registro BETWEEN pi_fecha_inicio AND pi_fecha_fin
            GROUP BY accion ORDER BY accion
        ) sub;

        SELECT COALESCE(jsonb_agg(row_data), '[]'::jsonb) INTO por_usuario
        FROM (
            SELECT jsonb_build_object(
                'usuario_id', hn.usuario_id, 'usuario_nombre', COALESCE(u.nombre, 'Sistema'), 'total', COUNT(*)
            ) AS row_data
            FROM public.historial_notas hn
            LEFT JOIN public.usuarios u ON hn.usuario_id = u.id
            WHERE hn.codhabcama = v_area_nombre AND hn.fecha_registro BETWEEN pi_fecha_inicio AND pi_fecha_fin
            GROUP BY hn.usuario_id, u.nombre ORDER BY COUNT(*) DESC
        ) sub;

        resultado := jsonb_build_object(
            'total', (SELECT COUNT(*) FROM public.historial_notas WHERE codhabcama = v_area_nombre AND fecha_registro BETWEEN pi_fecha_inicio AND pi_fecha_fin),
            'por_accion', por_accion, 'por_usuario', por_usuario
        );
        RETURN jsonb_build_object('estado', 'success', 'codigo', 200, 'mensaje', resultado);
    EXCEPTION
        WHEN OTHERS THEN RETURN jsonb_build_object('estado', 'error', 'codigo', 500, 'mensaje', SQLERRM);
    END;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION public.sp_analytics_ocupacion(
    pi_area_id INT, pi_fecha_inicio TIMESTAMP, pi_fecha_fin TIMESTAMP
)
RETURNS JSONB AS $$
DECLARE
    resultado JSONB;
    por_dia JSONB;
    v_area_nombre VARCHAR(255);
BEGIN
    BEGIN
        SELECT nombre INTO v_area_nombre FROM public.areas WHERE id = pi_area_id;

        SELECT jsonb_build_object(
            'total_ingresos', COUNT(*) FILTER (WHERE accion = 'INGRESO'),
            'total_egresos', COUNT(*) FILTER (WHERE accion = 'EGRESO'),
            'ocupacion_actual', (SELECT COUNT(*) FROM public.camas_essi WHERE "codHabCama" = v_area_nombre AND estado = TRUE AND "apeNomPac" != ''),
            'total_camas', (SELECT COUNT(*) FROM public.camas_essi WHERE "codHabCama" = v_area_nombre AND estado = TRUE)
        ) INTO resultado
        FROM public.historial_ocupacion
        WHERE codhabcama = v_area_nombre AND fecha_evento BETWEEN pi_fecha_inicio AND pi_fecha_fin;

        SELECT COALESCE(jsonb_agg(row_data ORDER BY fecha), '[]'::jsonb) INTO por_dia
        FROM (
            SELECT jsonb_build_object(
                'fecha', fecha_evento::date,
                'ingresos', COUNT(*) FILTER (WHERE accion = 'INGRESO'),
                'egresos', COUNT(*) FILTER (WHERE accion = 'EGRESO')
            ) AS row_data, fecha_evento::date AS fecha
            FROM public.historial_ocupacion
            WHERE codhabcama = v_area_nombre AND fecha_evento BETWEEN pi_fecha_inicio AND pi_fecha_fin
            GROUP BY fecha_evento::date
        ) sub;

        resultado := resultado || jsonb_build_object('por_dia', por_dia);
        RETURN jsonb_build_object('estado', 'success', 'codigo', 200, 'mensaje', resultado);
    EXCEPTION
        WHEN OTHERS THEN RETURN jsonb_build_object('estado', 'error', 'codigo', 500, 'mensaje', SQLERRM);
    END;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION public.sp_analytics_frecuencia_alertas(
    pi_area_id INT, pi_fecha_inicio TIMESTAMP, pi_fecha_fin TIMESTAMP
)
RETURNS JSONB AS $$
DECLARE
    resultado JSONB;
    por_hora JSONB;
    por_dia_semana JSONB;
    por_habitacion JSONB;
BEGIN
    BEGIN
        SELECT jsonb_build_object(
            'total_alertas', COUNT(*),
            'alertas_tipo_1', COUNT(*) FILTER (WHERE tipo_alerta = 1),
            'alertas_tipo_2', COUNT(*) FILTER (WHERE tipo_alerta = 2)
        ) INTO resultado
        FROM public.historial_alertas
        WHERE area_id = pi_area_id AND fecha_alerta BETWEEN pi_fecha_inicio AND pi_fecha_fin;

        SELECT COALESCE(jsonb_agg(row_data ORDER BY hora), '[]'::jsonb) INTO por_hora
        FROM (
            SELECT jsonb_build_object('hora', EXTRACT(HOUR FROM fecha_alerta)::int, 'total', COUNT(*)) AS row_data,
                   EXTRACT(HOUR FROM fecha_alerta)::int AS hora
            FROM public.historial_alertas
            WHERE area_id = pi_area_id AND fecha_alerta BETWEEN pi_fecha_inicio AND pi_fecha_fin
            GROUP BY EXTRACT(HOUR FROM fecha_alerta)::int
        ) sub;

        SELECT COALESCE(jsonb_agg(row_data ORDER BY dia), '[]'::jsonb) INTO por_dia_semana
        FROM (
            SELECT jsonb_build_object(
                'dia', EXTRACT(DOW FROM fecha_alerta)::int,
                'nombre', CASE EXTRACT(DOW FROM fecha_alerta)::int
                    WHEN 0 THEN 'Domingo' WHEN 1 THEN 'Lunes' WHEN 2 THEN 'Martes'
                    WHEN 3 THEN 'Miercoles' WHEN 4 THEN 'Jueves' WHEN 5 THEN 'Viernes' WHEN 6 THEN 'Sabado'
                END,
                'total', COUNT(*)
            ) AS row_data, EXTRACT(DOW FROM fecha_alerta)::int AS dia
            FROM public.historial_alertas
            WHERE area_id = pi_area_id AND fecha_alerta BETWEEN pi_fecha_inicio AND pi_fecha_fin
            GROUP BY EXTRACT(DOW FROM fecha_alerta)::int
        ) sub;

        SELECT COALESCE(jsonb_agg(row_data), '[]'::jsonb) INTO por_habitacion
        FROM (
            SELECT jsonb_build_object(
                'habitacion_id', habitacion_id, 'total', COUNT(*),
                'tipo_1', COUNT(*) FILTER (WHERE tipo_alerta = 1),
                'tipo_2', COUNT(*) FILTER (WHERE tipo_alerta = 2)
            ) AS row_data
            FROM public.historial_alertas
            WHERE area_id = pi_area_id AND fecha_alerta BETWEEN pi_fecha_inicio AND pi_fecha_fin
            GROUP BY habitacion_id ORDER BY COUNT(*) DESC
        ) sub;

        resultado := resultado || jsonb_build_object('por_hora', por_hora, 'por_dia_semana', por_dia_semana, 'por_habitacion', por_habitacion);
        RETURN jsonb_build_object('estado', 'success', 'codigo', 200, 'mensaje', resultado);
    EXCEPTION
        WHEN OTHERS THEN RETURN jsonb_build_object('estado', 'error', 'codigo', 500, 'mensaje', SQLERRM);
    END;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- VERIFICACION FINAL
-- =====================================================
DO $$
DECLARE
    v_tablas INT;
    v_funciones INT;
    v_triggers INT;
    v_indices INT;
BEGIN
    SELECT COUNT(*) INTO v_tablas FROM information_schema.tables WHERE table_schema = 'public' AND table_type = 'BASE TABLE';
    SELECT COUNT(*) INTO v_funciones FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid WHERE n.nspname = 'public' AND p.prokind = 'f';
    SELECT COUNT(*) INTO v_triggers FROM information_schema.triggers WHERE trigger_schema = 'public';
    SELECT COUNT(*) INTO v_indices FROM pg_indexes WHERE schemaname = 'public';

    RAISE NOTICE '';
    RAISE NOTICE '================================================';
    RAISE NOTICE '  SETUP COMPLETADO EXITOSAMENTE';
    RAISE NOTICE '================================================';
    RAISE NOTICE '  Tablas creadas:     %', v_tablas;
    RAISE NOTICE '  Funciones creadas:  %', v_funciones;
    RAISE NOTICE '  Triggers creados:   %', v_triggers;
    RAISE NOTICE '  Indices creados:    %', v_indices;
    RAISE NOTICE '================================================';
    RAISE NOTICE '  Siguiente paso: Importar datos desde CSV';
    RAISE NOTICE '  (ver GUIA_CONSTRUCCION_BD.md)';
    RAISE NOTICE '================================================';
END $$;
