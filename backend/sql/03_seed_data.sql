-- =====================================================
-- SCRIPT DE DATOS INICIALES - Sistema Llamado Enfermeras
-- =====================================================
-- Ejecutar después de crear las tablas y funciones
-- Orden de ejecución:
--   1. postgress.sql (tablas)
--   2. src/function/*.sql (funciones)
--   3. Este archivo (datos iniciales)
-- =====================================================

-- =====================================================
-- 1. CREAR HOSPITAL POR DEFECTO
-- =====================================================
INSERT INTO hospitales (
    cod_renaes, cod_ses, cod_eess, tipo_ra1, tipo, nombre,
    departamento, provincia, distrito, categoria, latitud, longitud,
    estado, enlace, fecha_registro, fecha_modificacion
)
VALUES (
    1, 1, 1, 'C', 'Hospital', 'Hospital Principal',
    'Lima', 'Lima', 'Lima', 'III-1', -12.046374, -77.042793,
    'FUNCIONA', '', NOW(), NOW()
)
ON CONFLICT (cod_ses) DO NOTHING;

-- =====================================================
-- 2. CREAR ÁREA POR DEFECTO (UCI)
-- =====================================================
INSERT INTO areas (id, cod_ses, nombre, estado, fecha_registro, fecha_modificacion)
VALUES (1, 1, 'UCI', true, NOW(), NOW())
ON CONFLICT (id) DO NOTHING;

-- =====================================================
-- 3. CREAR USUARIO ADMINISTRADOR
-- =====================================================
-- Contraseña: CAMBIA_ESTA_PASSWORD (hasheada con bcrypt)
INSERT INTO usuarios (nombre, usuario, clave, estado, fecha_registro, fecha_modificacion)
VALUES (
    'Admin Sistema',
    'admin',
    '$2b$10$N9qo8uLOickgx2ZMRZoMye.IjqQBrlJN3z.PxyF9Fy5SYz6F2CfGC',  -- CAMBIA_ESTA_PASSWORD
    true,
    NOW(),
    NOW()
)
ON CONFLICT (usuario) DO NOTHING;

-- =====================================================
-- 4. ASIGNAR USUARIO AL ÁREA
-- =====================================================
DO $$
DECLARE
    v_usuario_id INT;
BEGIN
    -- Obtener el ID del usuario admin
    SELECT id INTO v_usuario_id FROM usuarios WHERE usuario = 'admin' LIMIT 1;

    -- Si existe el usuario, crear la asignación
    IF v_usuario_id IS NOT NULL THEN
        -- Verificar si ya existe la asignación
        IF NOT EXISTS (
            SELECT 1 FROM asignaciones_usuarios
            WHERE usuario_id = v_usuario_id AND area_id = 1
        ) THEN
            INSERT INTO asignaciones_usuarios (usuario_id, area_id, rol, estado, fecha_registro, fecha_modificacion)
            VALUES (v_usuario_id, 1, 'admin', true, NOW(), NOW());

            RAISE NOTICE '✓ Usuario admin (ID: %) asignado al área UCI', v_usuario_id;
        ELSE
            RAISE NOTICE '→ Asignación ya existe para usuario admin';
        END IF;
    ELSE
        RAISE NOTICE '✗ No se encontró el usuario admin';
    END IF;
END $$;

-- =====================================================
-- 5. VERIFICAR DATOS CREADOS
-- =====================================================
DO $$
DECLARE
    v_hospitales INT;
    v_areas INT;
    v_usuarios INT;
    v_asignaciones INT;
BEGIN
    SELECT COUNT(*) INTO v_hospitales FROM hospitales;
    SELECT COUNT(*) INTO v_areas FROM areas;
    SELECT COUNT(*) INTO v_usuarios FROM usuarios;
    SELECT COUNT(*) INTO v_asignaciones FROM asignaciones_usuarios;

    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'RESUMEN DE DATOS INICIALES';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Hospitales:    %', v_hospitales;
    RAISE NOTICE 'Áreas:         %', v_areas;
    RAISE NOTICE 'Usuarios:      %', v_usuarios;
    RAISE NOTICE 'Asignaciones:  %', v_asignaciones;
    RAISE NOTICE '========================================';
    RAISE NOTICE '';
    RAISE NOTICE 'CREDENCIALES DE ACCESO:';
    RAISE NOTICE '  Usuario:     admin';
    RAISE NOTICE '  Contraseña:  CAMBIA_ESTA_PASSWORD';
    RAISE NOTICE '========================================';
END $$;
