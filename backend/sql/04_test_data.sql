-- =====================================================
-- SCRIPT DE DATOS DE PRUEBA - Sistema Llamado Enfermeras
-- =====================================================
-- Ejecutar DESPUÉS de 03_seed_data.sql
-- Este script crea datos ficticios para probar el sistema
-- sin necesidad de conexión a la API EsSi
-- =====================================================

-- =====================================================
-- 1. CREAR HABITACIONES DE PRUEBA
-- =====================================================
-- Habitaciones para el área UCI (area_id = 1)

INSERT INTO habitaciones (area_id, nombre, estado, fecha_registro, fecha_modificacion)
VALUES
    (1, 101, true, NOW(), NOW()),
    (1, 102, true, NOW(), NOW()),
    (1, 103, true, NOW(), NOW()),
    (1, 104, true, NOW(), NOW()),
    (1, 105, true, NOW(), NOW())
ON CONFLICT DO NOTHING;

-- =====================================================
-- 2. CREAR CAMAS DE PRUEBA CON PACIENTES
-- =====================================================
-- Obtener IDs de habitaciones y crear camas

DO $$
DECLARE
    v_hab_101 INT;
    v_hab_102 INT;
    v_hab_103 INT;
    v_hab_104 INT;
    v_hab_105 INT;
BEGIN
    -- Obtener IDs de habitaciones
    SELECT id INTO v_hab_101 FROM habitaciones WHERE nombre = 101 AND area_id = 1 LIMIT 1;
    SELECT id INTO v_hab_102 FROM habitaciones WHERE nombre = 102 AND area_id = 1 LIMIT 1;
    SELECT id INTO v_hab_103 FROM habitaciones WHERE nombre = 103 AND area_id = 1 LIMIT 1;
    SELECT id INTO v_hab_104 FROM habitaciones WHERE nombre = 104 AND area_id = 1 LIMIT 1;
    SELECT id INTO v_hab_105 FROM habitaciones WHERE nombre = 105 AND area_id = 1 LIMIT 1;

    -- Habitación 101 - 3 camas
    IF v_hab_101 IS NOT NULL THEN
        INSERT INTO camas (habitacion_id, nombre, paciente, estado, fecha_registro, fecha_modificacion)
        VALUES
            (v_hab_101, 'A', 'GARCIA LOPEZ, MARIA ELENA', true, NOW(), NOW()),
            (v_hab_101, 'B', 'RODRIGUEZ PEREZ, JUAN CARLOS', true, NOW(), NOW()),
            (v_hab_101, 'C', 'Baño', true, NOW(), NOW())
        ON CONFLICT DO NOTHING;
        RAISE NOTICE '✓ Camas creadas para habitación 101';
    END IF;

    -- Habitación 102 - 3 camas
    IF v_hab_102 IS NOT NULL THEN
        INSERT INTO camas (habitacion_id, nombre, paciente, estado, fecha_registro, fecha_modificacion)
        VALUES
            (v_hab_102, 'A', 'MARTINEZ SANCHEZ, ANA LUCIA', true, NOW(), NOW()),
            (v_hab_102, 'B', 'FERNANDEZ DIAZ, PEDRO MIGUEL', true, NOW(), NOW()),
            (v_hab_102, 'C', 'TORRES RUIZ, CARMEN ROSA', true, NOW(), NOW())
        ON CONFLICT DO NOTHING;
        RAISE NOTICE '✓ Camas creadas para habitación 102';
    END IF;

    -- Habitación 103 - 2 camas
    IF v_hab_103 IS NOT NULL THEN
        INSERT INTO camas (habitacion_id, nombre, paciente, estado, fecha_registro, fecha_modificacion)
        VALUES
            (v_hab_103, 'A', 'LOPEZ VARGAS, ROBERTO LUIS', true, NOW(), NOW()),
            (v_hab_103, 'B', 'CASTRO MENDOZA, SOFIA MARIA', true, NOW(), NOW())
        ON CONFLICT DO NOTHING;
        RAISE NOTICE '✓ Camas creadas para habitación 103';
    END IF;

    -- Habitación 104 - 3 camas
    IF v_hab_104 IS NOT NULL THEN
        INSERT INTO camas (habitacion_id, nombre, paciente, estado, fecha_registro, fecha_modificacion)
        VALUES
            (v_hab_104, 'A', 'RAMIREZ FLORES, JOSE ANTONIO', true, NOW(), NOW()),
            (v_hab_104, 'B', 'Baño', true, NOW(), NOW()),
            (v_hab_104, 'C', 'MORALES CRUZ, LUCIA PATRICIA', true, NOW(), NOW())
        ON CONFLICT DO NOTHING;
        RAISE NOTICE '✓ Camas creadas para habitación 104';
    END IF;

    -- Habitación 105 - 2 camas
    IF v_hab_105 IS NOT NULL THEN
        INSERT INTO camas (habitacion_id, nombre, paciente, estado, fecha_registro, fecha_modificacion)
        VALUES
            (v_hab_105, 'A', 'HERNANDEZ VEGA, CARLOS EDUARDO', true, NOW(), NOW()),
            (v_hab_105, 'B', 'SILVA TORRES, MARIA FERNANDA', true, NOW(), NOW())
        ON CONFLICT DO NOTHING;
        RAISE NOTICE '✓ Camas creadas para habitación 105';
    END IF;

END $$;

-- =====================================================
-- 3. CREAR DISPOSITIVO ESP32 DE PRUEBA
-- =====================================================
INSERT INTO esp32_dispositivos (numero_serial, direccion_mac, ip, estado, fecha_registro, fecha_modificacion)
VALUES ('TEST00000001', 'AA:BB:CC:DD:EE:01', '192.168.1.100', true, NOW(), NOW())
ON CONFLICT (numero_serial) DO NOTHING;

-- =====================================================
-- 4. CREAR ALGUNAS ALERTAS DE PRUEBA (OPCIONAL)
-- =====================================================
DO $$
DECLARE
    v_dispositivo_id INT;
    v_hab_101 INT;
    v_hab_103 INT;
BEGIN
    -- Obtener IDs necesarios
    SELECT id INTO v_dispositivo_id FROM esp32_dispositivos WHERE numero_serial = 'TEST00000001' LIMIT 1;
    SELECT id INTO v_hab_101 FROM habitaciones WHERE nombre = 101 AND area_id = 1 LIMIT 1;
    SELECT id INTO v_hab_103 FROM habitaciones WHERE nombre = 103 AND area_id = 1 LIMIT 1;

    IF v_dispositivo_id IS NOT NULL AND v_hab_101 IS NOT NULL THEN
        -- Alerta urgente en habitación 101, cama A
        INSERT INTO alertas (dispositivo_id, area_id, habitacion_id, codigo_cama, tipo_alerta, estado_alerta, fecha_registro, fecha_modificacion)
        VALUES (v_dispositivo_id, 1, v_hab_101, 'A', 1, true, NOW(), NOW())
        ON CONFLICT DO NOTHING;
        RAISE NOTICE '✓ Alerta de prueba creada en habitación 101';
    END IF;

    IF v_dispositivo_id IS NOT NULL AND v_hab_103 IS NOT NULL THEN
        -- Alerta crítica en habitación 103, cama B
        INSERT INTO alertas (dispositivo_id, area_id, habitacion_id, codigo_cama, tipo_alerta, estado_alerta, fecha_registro, fecha_modificacion)
        VALUES (v_dispositivo_id, 1, v_hab_103, 'B', 2, true, NOW(), NOW())
        ON CONFLICT DO NOTHING;
        RAISE NOTICE '✓ Alerta crítica de prueba creada en habitación 103';
    END IF;

END $$;

-- =====================================================
-- 5. VERIFICAR DATOS CREADOS
-- =====================================================
DO $$
DECLARE
    v_habitaciones INT;
    v_camas INT;
    v_dispositivos INT;
    v_alertas INT;
BEGIN
    SELECT COUNT(*) INTO v_habitaciones FROM habitaciones WHERE area_id = 1;
    SELECT COUNT(*) INTO v_camas FROM camas c JOIN habitaciones h ON c.habitacion_id = h.id WHERE h.area_id = 1;
    SELECT COUNT(*) INTO v_dispositivos FROM esp32_dispositivos;
    SELECT COUNT(*) INTO v_alertas FROM alertas WHERE estado_alerta = true;

    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'RESUMEN DE DATOS DE PRUEBA';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Habitaciones en UCI:  %', v_habitaciones;
    RAISE NOTICE 'Camas totales:        %', v_camas;
    RAISE NOTICE 'Dispositivos ESP32:   %', v_dispositivos;
    RAISE NOTICE 'Alertas activas:      %', v_alertas;
    RAISE NOTICE '========================================';
    RAISE NOTICE '';
    RAISE NOTICE 'DATOS DE PRUEBA LISTOS';
    RAISE NOTICE 'Ahora puedes probar el sistema con:';
    RAISE NOTICE '  Usuario:     admin';
    RAISE NOTICE '  Contraseña:  CAMBIA_ESTA_PASSWORD';
    RAISE NOTICE '========================================';
END $$;
