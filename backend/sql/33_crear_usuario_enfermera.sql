-- =====================================================
-- Crear usuario enfermera con acceso limitado
-- =====================================================
-- Acceso: Principal + Contenido TV (solo lectura)
-- Sin acceso a: Analytics, Dispositivos
-- =====================================================
-- Credenciales:
--   Usuario:     enfermera
--   Contraseña:  enfermera123
-- =====================================================

-- 1. Crear el usuario
INSERT INTO usuarios (nombre, usuario, clave, estado, fecha_registro, fecha_modificacion)
VALUES (
    'Enfermera',
    'enfermera',
    '$2b$10$8FSzN97ApXd151l4kkgTd.NOG.U/f6lZ59IjD34ETDxon6opn6t9q',  -- enfermera123
    true,
    NOW(),
    NOW()
)
ON CONFLICT (usuario) DO NOTHING;

-- 2. Asignar al area con rol 'enfermera'
-- IMPORTANTE: Cambia el area_id segun tu area
-- Para ver las areas disponibles: SELECT id, nombre FROM areas WHERE estado = true;
DO $$
DECLARE
    v_usuario_id INT;
    v_area_id INT;
BEGIN
    -- Obtener ID del usuario creado
    SELECT id INTO v_usuario_id FROM usuarios WHERE usuario = 'enfermera' LIMIT 1;

    -- Obtener la primera area activa (cambia esto si necesitas otra area)
    SELECT id INTO v_area_id FROM areas WHERE estado = true ORDER BY id LIMIT 1;

    IF v_usuario_id IS NOT NULL AND v_area_id IS NOT NULL THEN
        -- Verificar si ya existe la asignacion
        IF NOT EXISTS (
            SELECT 1 FROM asignaciones_usuarios
            WHERE usuario_id = v_usuario_id AND area_id = v_area_id
        ) THEN
            INSERT INTO asignaciones_usuarios (usuario_id, area_id, rol, estado, fecha_registro, fecha_modificacion)
            VALUES (v_usuario_id, v_area_id, 'enfermera', true, NOW(), NOW());

            RAISE NOTICE 'Usuario enfermera (ID: %) asignado al area ID: % con rol enfermera', v_usuario_id, v_area_id;
        ELSE
            RAISE NOTICE 'Asignacion ya existe para usuario enfermera en area %', v_area_id;
        END IF;
    ELSE
        RAISE NOTICE 'Error: usuario_id=%, area_id=%', v_usuario_id, v_area_id;
    END IF;
END $$;

-- 3. Verificar
SELECT u.id, u.nombre, u.usuario, au.rol, a.nombre as area
FROM usuarios u
JOIN asignaciones_usuarios au ON u.id = au.usuario_id
JOIN areas a ON au.area_id = a.id
WHERE u.usuario = 'enfermera';
