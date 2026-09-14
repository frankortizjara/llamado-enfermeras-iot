-- =====================================================
-- SISTEMA LLAMADO DE ENFERMERAS
-- Script completo de base de datos
-- =====================================================
-- Ejecutar este archivo para crear toda la base de datos
-- desde cero en un nuevo servidor/PC
-- =====================================================
-- Orden: Tablas -> Triggers -> Funciones -> Datos iniciales
-- =====================================================

-- =====================================================
-- PARTE 1: TABLAS
-- =====================================================

-- Tabla usuarios
CREATE TABLE IF NOT EXISTS usuarios (
  id SERIAL PRIMARY KEY,
  nombre VARCHAR(255) NOT NULL,
  usuario VARCHAR(255) UNIQUE NOT NULL,
  clave VARCHAR(255) NOT NULL,
  estado BOOLEAN NOT NULL DEFAULT true,
  fecha_registro TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  fecha_modificacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Tabla hospitales
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

-- Tabla áreas
CREATE TABLE IF NOT EXISTS areas (
  id SERIAL PRIMARY KEY,
  cod_ses INTEGER NOT NULL,
  nombre VARCHAR(255) NOT NULL,
  estado BOOLEAN NOT NULL DEFAULT true,
  fecha_registro TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  fecha_modificacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_hospitales_cod_ses FOREIGN KEY (cod_ses) REFERENCES hospitales (cod_ses)
);

-- Tabla habitaciones
CREATE TABLE IF NOT EXISTS habitaciones (
  id SERIAL PRIMARY KEY,
  area_id INTEGER NOT NULL,
  nombre INTEGER NOT NULL,
  estado BOOLEAN NOT NULL DEFAULT true,
  fecha_registro TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  fecha_modificacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_areas FOREIGN KEY (area_id) REFERENCES areas (id)
);

-- Tabla camas
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

-- Tabla camas EsSi (datos de pacientes externos)
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
  nota VARCHAR(4) DEFAULT '',
  fecha_nota VARCHAR(255) DEFAULT '',
  estado BOOLEAN NOT NULL DEFAULT TRUE,
  fecha_registro TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  fecha_modificacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Tabla dispositivos ESP32
CREATE TABLE IF NOT EXISTS esp32_dispositivos (
  id SERIAL PRIMARY KEY,
  numero_serial VARCHAR(12) UNIQUE NOT NULL,
  direccion_mac VARCHAR(17) UNIQUE NOT NULL,
  ip VARCHAR(45),
  estado BOOLEAN NOT NULL DEFAULT true,
  fecha_registro TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  fecha_modificacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Tabla alertas
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

-- Tabla asignaciones de usuarios a áreas
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

-- Tabla variables del sistema
CREATE TABLE IF NOT EXISTS variables (
  id SERIAL PRIMARY KEY,
  nombre_variable VARCHAR(50) NOT NULL
);

-- =====================================================
-- PARTE 2: TRIGGERS
-- =====================================================

-- Función para actualizar fecha_modificacion
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

-- Triggers para cada tabla
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
-- PARTE 3: FUNCIONES DE USUARIOS
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
-- PARTE 4: FUNCIONES DE DISPOSITIVOS
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

CREATE OR REPLACE FUNCTION public.sp_agregar_registro(
    pi_numero_serial text, pi_area_id int, pi_habitacion_id int, pi_codigo_cama text, pi_tipo_alerta int
)
RETURNS JSONB AS $$
DECLARE
    resultado JSONB;
    v_dispositivo_id int;
    alerta RECORD;
BEGIN
    BEGIN
        SELECT id INTO v_dispositivo_id FROM public.esp32_dispositivos WHERE numero_serial = pi_numero_serial;

        IF v_dispositivo_id IS NOT NULL THEN
            IF pi_tipo_alerta = 1 OR pi_tipo_alerta = 2 THEN
                FOR alerta IN
                    SELECT id FROM public.alertas
                    WHERE dispositivo_id = v_dispositivo_id AND area_id = pi_area_id
                    AND habitacion_id = pi_habitacion_id AND codigo_cama = pi_codigo_cama
                    AND tipo_alerta = pi_tipo_alerta AND estado_alerta = true
                LOOP
                    RETURN jsonb_build_object('estado', 'success', 'codigo', 409, 'mensaje', 'Registro aún sin atender');
                END LOOP;

                INSERT INTO public.alertas (dispositivo_id, area_id, habitacion_id, codigo_cama, tipo_alerta, fecha_registro, fecha_modificacion)
                VALUES (v_dispositivo_id, pi_area_id, pi_habitacion_id, pi_codigo_cama, pi_tipo_alerta, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);
                RETURN jsonb_build_object('estado', 'success', 'codigo', 201, 'mensaje', 'Registro agregado correctamente');

            ELSIF pi_tipo_alerta = 3 THEN
                FOR alerta IN
                    SELECT id FROM public.alertas
                    WHERE dispositivo_id = v_dispositivo_id AND area_id = pi_area_id
                    AND habitacion_id = pi_habitacion_id AND codigo_cama = pi_codigo_cama AND estado_alerta = true
                LOOP
                    UPDATE public.alertas SET estado_alerta = FALSE, fecha_modificacion = CURRENT_TIMESTAMP WHERE id = alerta.id;
                END LOOP;

                IF FOUND THEN
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

-- =====================================================
-- PARTE 5: FUNCIONES DE INFORMACIÓN
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
BEGIN
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

    RETURN jsonb_build_object('estado', 'success', 'codigo', 200, 'mensaje', habitaciones_json);
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

CREATE OR REPLACE FUNCTION public.sp_cargar_data_essi(
    apeNomPac VARCHAR, codHabCama VARCHAR, codHab VARCHAR, codCama VARCHAR, desEstCama VARCHAR,
    desSerCama VARCHAR, diashospi VARCHAR, fechaIngreso VARCHAR, nroDocIdePac VARCHAR, nroHisCliCas VARCHAR, tipoDocIdePac VARCHAR
)
RETURNS JSONB AS $$
BEGIN
    IF EXISTS (SELECT 1 FROM camas_essi WHERE "codHabCama" = codHabCama AND "codHab" = codHab AND "codCama" = codCama AND "nroDocIdePac" = nroDocIdePac) THEN
        RETURN jsonb_build_object('estado', 'error', 'codigo', 409, 'mensaje', 'El registro ya existe');
    ELSE
        IF EXISTS (SELECT 1 FROM camas_essi WHERE "codHabCama" = codHabCama AND "codHab" = codHab AND "codCama" = codCama) THEN
            UPDATE camas_essi SET estado = FALSE WHERE "codHabCama" = codHabCama AND "codHab" = codHab AND "codCama" = codCama;
        END IF;

        INSERT INTO camas_essi ("codHabCama", "codHab", "codCama", "apeNomPac", "desEstCama", "desSerCama", "diashospi", "fechaIngreso", "nroDocIdePac", "nroHisCliCas", "tipoDocIdePac", estado)
        VALUES (codHabCama, codHab, codCama, apeNomPac, desEstCama, desSerCama, diashospi, fechaIngreso, nroDocIdePac, nroHisCliCas, tipoDocIdePac, TRUE);

        RETURN jsonb_build_object('estado', 'success', 'codigo', 200, 'mensaje', 'Registro insertado exitosamente');
    END IF;
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

CREATE OR REPLACE FUNCTION public.sp_editar_nota(pi_id INT, pi_nota TEXT, pi_fecha_nota TEXT)
RETURNS JSONB AS $$
DECLARE
    resultado JSONB;
BEGIN
    BEGIN
        UPDATE public.camas_essi SET nota = pi_nota, fecha_nota = pi_fecha_nota, fecha_modificacion = CURRENT_TIMESTAMP WHERE id = pi_id;
        IF FOUND THEN
            resultado := jsonb_build_object('estado', 'success', 'codigo', 200, 'mensaje', 'Nota actualizada');
        ELSE
            resultado := jsonb_build_object('estado', 'error', 'codigo', 404, 'mensaje', 'Nota no encontrada');
        END IF;
        RETURN resultado;
    EXCEPTION
        WHEN OTHERS THEN RETURN jsonb_build_object('estado', 'error', 'codigo', 500, 'mensaje', SQLERRM);
    END;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- PARTE 6: FUNCIONES DE AMBIENTES
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
-- PARTE 7: DATOS INICIALES
-- =====================================================

-- Hospital por defecto
INSERT INTO hospitales (cod_renaes, cod_ses, cod_eess, tipo_ra1, tipo, nombre, departamento, provincia, distrito, categoria, latitud, longitud, estado, enlace)
VALUES (1, 1, 1, 'C', 'Hospital', 'Hospital Principal', 'Lima', 'Lima', 'Lima', 'III-1', -12.046374, -77.042793, 'FUNCIONA', '')
ON CONFLICT (cod_ses) DO NOTHING;

-- Área UCI
INSERT INTO areas (id, cod_ses, nombre, estado, fecha_registro, fecha_modificacion)
VALUES (1, 1, 'UCI', true, NOW(), NOW())
ON CONFLICT (id) DO NOTHING;

-- Usuario administrador (contraseña: CAMBIA_ESTA_PASSWORD)
INSERT INTO usuarios (nombre, usuario, clave, estado, fecha_registro, fecha_modificacion)
VALUES ('Admin Sistema', 'admin', '$2b$10$TePIMUiEOu5BbymhTeFgHOMMIJWBZ3TAxm4F0Twy7pkFfOnb9KlLW', true, NOW(), NOW())
ON CONFLICT (usuario) DO NOTHING;

-- Asignar usuario al área
DO $$
DECLARE
    v_usuario_id INT;
BEGIN
    SELECT id INTO v_usuario_id FROM usuarios WHERE usuario = 'admin' LIMIT 1;
    IF v_usuario_id IS NOT NULL THEN
        IF NOT EXISTS (SELECT 1 FROM asignaciones_usuarios WHERE usuario_id = v_usuario_id AND area_id = 1) THEN
            INSERT INTO asignaciones_usuarios (usuario_id, area_id, rol, estado, fecha_registro, fecha_modificacion)
            VALUES (v_usuario_id, 1, 'admin', true, NOW(), NOW());
        END IF;
    END IF;
END $$;

-- =====================================================
-- FIN DEL SCRIPT
-- =====================================================
-- Credenciales de acceso:
--   Usuario: admin
--   Contraseña: CAMBIA_ESTA_PASSWORD
-- =====================================================
