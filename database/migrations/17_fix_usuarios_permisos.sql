-- =====================================================
-- MIGRACIÓN 36: Fix completo de usuarios, permisos y áreas
-- =====================================================
-- 1. Limpieza de asignaciones huérfanas y duplicadas
-- 2. Tabla servicios_hospitalarios (áreas con códigos EsSi)
-- 3. SP sp_asignar_usuario: UPSERT
-- 4. SP sp_eliminar_usuario: elimina asignaciones primero
-- 5. SP sp_listar_usuarios: incluye asignacion_id
-- 6. SP sp_obtener_usuario: incluye permisos y rol
-- 7. SP sp_listar_servicios_hospitalarios: para frontend
-- =====================================================

-- =====================================================
-- PASO 1: Limpieza de datos
-- =====================================================

-- Eliminar asignaciones huérfanas (usuario_id que no existe en usuarios)
DELETE FROM public.asignaciones_usuarios
WHERE usuario_id NOT IN (SELECT id FROM public.usuarios);

-- Eliminar asignaciones duplicadas (mantener solo la más reciente por usuario)
DELETE FROM public.asignaciones_usuarios a
USING public.asignaciones_usuarios b
WHERE a.usuario_id = b.usuario_id
  AND a.id < b.id;

-- =====================================================
-- PASO 2: Tabla servicios_hospitalarios
-- =====================================================
CREATE TABLE IF NOT EXISTS public.servicios_hospitalarios (
    id SERIAL PRIMARY KEY,
    servicio VARCHAR(255) NOT NULL,
    serv_hos_cod VARCHAR(20) NOT NULL,
    estacion VARCHAR(255) NOT NULL,
    est_enf_cod VARCHAR(20) NOT NULL,
    ori_cen_asi_cod VARCHAR(10) DEFAULT '1',
    cen_asi_cod VARCHAR(10) DEFAULT '005',
    are_hos_cod VARCHAR(10) DEFAULT '03',
    estado BOOLEAN DEFAULT TRUE,
    fecha_registro TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(servicio, est_enf_cod)
);

-- Insertar datos (solo si la tabla está vacía)
INSERT INTO public.servicios_hospitalarios (servicio, serv_hos_cod, estacion, est_enf_cod)
SELECT * FROM (VALUES
    -- HOSPITALIZACIÓN
    ('CIRUGIA GENERAL 1',            'B42',  'HOSP. CIRUGIA 1',        '19'),
    ('CIRUGIA GENERAL 1',            'B42',  'ANEXO ESPEC. QUIRURG',   '22'),
    ('CIRUGIA ONCOLOGICA',           'B39',  'CIR.ONCOLO.CONTING',     'QO'),
    ('CIRUGIA PEDIATRICA',           'D13',  'CIRUG_PEDIATRICA',       '38'),
    ('CIRUGIA PLASTICA',             'B51',  'CIRUGIA PLASTICA',       '23'),
    ('CIR. CABEZA Y CUELLO',         'B11',  'CIR_CABEZA Y CUE',       '17'),
    ('CIR. TORAX Y CARDIOVASCULAR',  'B31',  'CIR_CARDIOVASCU',        '18'),
    ('CARDIOLOGIA',                  'A21',  'CARDIOLOGIA CONTING',    'C'),
    ('DERMATOLOGIA',                 'A31',  'DERMATOLOGIA CONTING',   'DE'),
    ('ENDOCRINOLOGIA',               'A41',  'ENDOCRINOLOGIA',         '3'),
    ('GASTROENTEROLOGIA',            'A51',  'DEP ESPECIAL.MED III',   'GE'),
    ('GERIATRIA',                    'A71',  'DPTO.ESPEC.MEDIC I',     'GM'),
    ('GERIATRIA',                    'A71',  'GERIATRIA',              '6'),
    ('GINECOLOGIA',                  'C12',  'GINECOLOGIA',            '28'),
    ('GINECOLOGIA ONCOLOGICA',       'AG2',  'GINECO ONCO',            '42'),
    ('HEMATOLOGIA CLINICA',          'A81',  'HEMAT PEDIATR CONTING',  'HC'),
    ('INFECTOLOGIA',                 'AJ1',  'INFECTOLOGIA CONTING',   '16'),
    ('MEDICINA INTENSIVA (UCI)',      'AK1',  'CUID INTENSIVOS ADUL',   '28'),
    ('MEDICINA INTENSIVA (UCIN)',     'AK1',  'CUID INTERMEDIOS',       '29'),
    ('MEDICINA INTENSIVA (RESP.)',    'AK1',  'TERAPIA RESPIRATORIA',   'TR'),
    ('MEDICINA INTERNA',             'AC1',  'VARONES IV',             'I'),
    ('MEDICINA INTERNA',             'AC1',  'VARONES II',             'V2'),
    ('MEDICINA INTERNA',             'AC1',  'DAMAS I',                'MI'),
    ('MEDICINA INTERNA',             'AC1',  'UCEMI 1',                'NU'),
    ('MEDICINA INTERNA',             'AC1',  'UCEMI 2',                'N2'),
    ('MEDICINA INTERNA',             'AC1',  'UCEMI 3',                'N3'),
    ('MEDICINA INTERNA',             'AC1',  'ANEXO ESPEC. MEDICAS',   '26'),
    ('NEFROLOGIA',                   'AD1',  'NEFROLOGIA CONTING',     'EN'),
    ('NEONATOLOGIA',                 'D14',  'UCI NEONATALES',         'UN'),
    ('NEONATOLOGIA',                 'D14',  'UCIN NEONATOLOGIA A',    'UA'),
    ('NEONATOLOGIA',                 'D14',  'UCIN NEONATOLOGIA B',    'UB'),
    ('NEUMOLOGIA',                   'AE1',  'NEUMOLOGIA CONTING',     'EN'),
    ('NEUROCIRUGIA',                 'B61',  'NEUROCIRUGIA',           '24'),
    ('NEUROLOGIA',                   'AF1',  'DPTO. ESPEC.MEDIC I',    'NM'),
    ('NEUROLOGIA',                   'AF1',  'NEUROLOGIA CONTING',     'EN'),
    ('OBSTETRICIA',                  'C13',  'ARO',                    'AR'),
    ('OBSTETRICIA',                  'C13',  'PATOLOGIA I CONTING',    'P1'),
    ('OBSTETRICIA',                  'C13',  'PATOLOGIA II CONTING',   'P2'),
    ('ONCOLOGIA MEDICA',             'AG3',  'ONCOLOGIA CONTING',      'EN'),
    ('ORTOPEDIA Y TRAUMATOLOGIA',    'B81',  'TRAUMATOLOGIA CONTING',  'OT'),
    ('OTORRINOLARINGOLOGIA',         'B91',  'OTORRINO',               '26'),
    ('PEDIATRIA',                    'D11',  'PEDIATRIA CONTING',      '30'),
    ('PEDIATRIA (UCI)',               'D11',  'UCI PEDIATRIA',          '34'),
    ('PSIQUIATRIA',                  'AH1',  'DPTO.ESPEC.MEDIC I',     'EM'),
    ('REUMATOLOGIA',                 'AI1',  'SERV_CUIDADO',           '15'),
    ('UROLOGIA',                     'BA1',  'UROLOGIA ESPECIALIDA',   '27'),
    -- URGENCIAS/EMERGENCIA
    ('EMERGENCIA (Obs A)',            'AB1',  'OBSERVACION A',          'OA'),
    ('EMERGENCIA (Obs B)',            'AB1',  'OBSERVACION B',          'OB'),
    ('EMERGENCIA (Obs C-L)',          'AB1',  'OBSERVACION C..L',       'OC..OL'),
    -- CENTRO OBSTETRICO / QUIRURGICO
    ('OBSTETRICIA (Puerperio)',       'C13',  'PUERPERIO INMEDIATO',    'PI'),
    ('OBSTETRICIA (Sala Partos)',     'C13',  'SALA PARTOS',            'SP'),
    ('ANESTESIA/REANIMACION',        'BB1',  'CANTA CALLAO',           'CC'),
    ('ANESTESIA/REANIMACION',        'BB1',  'CENTRO QX (Recuper.)',   'CQ')
) AS t(servicio, serv_hos_cod, estacion, est_enf_cod)
WHERE NOT EXISTS (SELECT 1 FROM public.servicios_hospitalarios LIMIT 1);

-- SP para listar servicios hospitalarios (para el frontend)
CREATE OR REPLACE FUNCTION public.sp_listar_servicios_hospitalarios()
RETURNS JSONB AS $$
DECLARE
    resultado JSONB := '[]'::jsonb;
    registro RECORD;
BEGIN
    FOR registro IN
        SELECT id, servicio, serv_hos_cod, estacion, est_enf_cod,
               ori_cen_asi_cod, cen_asi_cod, are_hos_cod
        FROM public.servicios_hospitalarios
        WHERE estado = true
        ORDER BY servicio, estacion
    LOOP
        resultado := resultado || jsonb_build_object(
            'id', registro.id,
            'servicio', registro.servicio,
            'serv_hos_cod', registro.serv_hos_cod,
            'estacion', registro.estacion,
            'est_enf_cod', registro.est_enf_cod,
            'ori_cen_asi_cod', registro.ori_cen_asi_cod,
            'cen_asi_cod', registro.cen_asi_cod,
            'are_hos_cod', registro.are_hos_cod
        );
    END LOOP;

    RETURN jsonb_build_object('estado', 'success', 'codigo', 200, 'mensaje', resultado);
EXCEPTION
    WHEN OTHERS THEN RETURN jsonb_build_object('estado', 'error', 'codigo', 500, 'mensaje', SQLERRM);
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- PASO 3: Fix sp_asignar_usuario (UPSERT por usuario_id)
-- =====================================================
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
    existing_id INT;
BEGIN
    BEGIN
        -- Buscar asignación existente para este usuario
        SELECT id INTO existing_id
        FROM public.asignaciones_usuarios
        WHERE usuario_id = pi_usuario_id
        LIMIT 1;

        IF existing_id IS NOT NULL THEN
            -- Actualizar asignación existente
            UPDATE public.asignaciones_usuarios
            SET area_id = pi_area_id,
                rol = pi_rol,
                estado = pi_estado,
                permisos = pi_permisos,
                fecha_modificacion = CURRENT_TIMESTAMP
            WHERE id = existing_id;

            resultado := jsonb_build_object(
                'estado', 'success',
                'codigo', 200,
                'mensaje', 'Asignación actualizada',
                'id', existing_id
            );
        ELSE
            -- Crear nueva asignación
            INSERT INTO public.asignaciones_usuarios (usuario_id, area_id, rol, estado, permisos, fecha_registro, fecha_modificacion)
            VALUES (pi_usuario_id, pi_area_id, pi_rol, pi_estado, pi_permisos, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
            RETURNING id INTO existing_id;

            resultado := jsonb_build_object(
                'estado', 'success',
                'codigo', 201,
                'mensaje', 'Asignación creada',
                'id', existing_id
            );
        END IF;

        RETURN resultado;

    EXCEPTION
        WHEN OTHERS THEN
            RETURN jsonb_build_object(
                'estado', 'error',
                'codigo', 500,
                'mensaje', SQLERRM
            );
    END;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- PASO 4: Fix sp_eliminar_usuario (cascade assignments)
-- =====================================================
CREATE OR REPLACE FUNCTION public.sp_eliminar_usuario(pi_id INT)
RETURNS JSONB AS $$
DECLARE
    resultado JSONB;
BEGIN
    BEGIN
        -- Eliminar asignaciones del usuario primero
        DELETE FROM public.asignaciones_usuarios WHERE usuario_id = pi_id;

        -- Luego eliminar el usuario
        DELETE FROM public.usuarios WHERE id = pi_id;

        IF FOUND THEN
            resultado := jsonb_build_object(
                'estado', 'success',
                'codigo', 200,
                'mensaje', 'Usuario eliminado correctamente'
            );
        ELSE
            resultado := jsonb_build_object(
                'estado', 'error',
                'codigo', 404,
                'mensaje', 'Usuario no encontrado'
            );
        END IF;

        RETURN resultado;
    EXCEPTION
        WHEN foreign_key_violation THEN
            RETURN jsonb_build_object(
                'estado', 'error',
                'codigo', 409,
                'mensaje', 'No se puede eliminar: el usuario tiene datos asociados'
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

-- =====================================================
-- PASO 5: Fix sp_listar_usuarios (incluye asignacion_id)
-- =====================================================
CREATE OR REPLACE FUNCTION public.sp_listar_usuarios()
RETURNS JSONB AS $$
DECLARE
    resultado JSONB := '[]'::jsonb;
    registro RECORD;
BEGIN
    FOR registro IN
        SELECT u.id, u.nombre, u.usuario, u.estado,
               au.id AS asignacion_id,
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
            'asignacion_id', registro.asignacion_id,
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

-- =====================================================
-- PASO 6: Fix sp_obtener_usuario (login con permisos)
-- =====================================================
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
            'permisos', COALESCE(au.permisos, '{}'::jsonb),
            'estado', u.estado
        ) INTO resultado
        FROM public.usuarios u
        LEFT JOIN public.asignaciones_usuarios au ON u.id = au.usuario_id AND au.estado = true
        LEFT JOIN public.areas ar ON au.area_id = ar.id
        WHERE u.usuario = pi_usuario
        LIMIT 1;

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
