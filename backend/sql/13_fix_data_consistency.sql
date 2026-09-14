-- =====================================================
-- FIX: Corregir inconsistencias de datos
-- =====================================================

SET search_path TO public;

-- =====================================================
-- 1. FIX: esp32_dispositivos - copiar datos de serial/mac
-- =====================================================
DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE '1. CORRIGIENDO esp32_dispositivos';
    RAISE NOTICE '========================================';
END $$;

-- Verificar si existen las columnas serial y mac
DO $$
DECLARE
    tiene_serial BOOLEAN;
    tiene_mac BOOLEAN;
BEGIN
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'esp32_dispositivos' AND column_name = 'serial'
    ) INTO tiene_serial;

    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'esp32_dispositivos' AND column_name = 'mac'
    ) INTO tiene_mac;

    IF tiene_serial AND tiene_mac THEN
        -- Copiar datos de serial a numero_serial (limitando a 12 chars)
        UPDATE esp32_dispositivos
        SET numero_serial = LEFT(serial, 12)
        WHERE numero_serial IS NULL AND serial IS NOT NULL;

        -- Copiar datos de mac a direccion_mac (limitando a 17 chars)
        UPDATE esp32_dispositivos
        SET direccion_mac = LEFT(mac, 17)
        WHERE direccion_mac IS NULL AND mac IS NOT NULL;

        RAISE NOTICE 'Datos copiados de serial/mac a numero_serial/direccion_mac';
    ELSE
        RAISE NOTICE 'Las columnas serial/mac no existen';
    END IF;
END $$;

-- Asegurarse de que hay al menos un dispositivo válido para pruebas
-- Serial de 12 caracteres máximo
INSERT INTO esp32_dispositivos (numero_serial, direccion_mac, ip, estado, fecha_registro, fecha_modificacion)
SELECT 'TESTDEV00001', 'AA:BB:CC:DD:EE:FF', '192.168.1.100', true, NOW(), NOW()
WHERE NOT EXISTS (
    SELECT 1 FROM esp32_dispositivos WHERE numero_serial = 'TESTDEV00001'
);

-- Mostrar dispositivos disponibles
DO $$
DECLARE
    rec RECORD;
    contador INT := 0;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE 'Dispositivos ESP32 disponibles:';
    FOR rec IN
        SELECT id, numero_serial, direccion_mac, ip
        FROM esp32_dispositivos
        WHERE numero_serial IS NOT NULL
        LIMIT 10
    LOOP
        contador := contador + 1;
        RAISE NOTICE '  ID: %, Serial: %, MAC: %', rec.id, rec.numero_serial, rec.direccion_mac;
    END LOOP;

    IF contador = 0 THEN
        RAISE NOTICE '  (No hay dispositivos con numero_serial valido)';
    END IF;
END $$;

-- =====================================================
-- 2. FIX: habitaciones - agregar las que faltan
-- =====================================================
DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE '2. SINCRONIZANDO habitaciones con camas_essi';
    RAISE NOTICE '========================================';
END $$;

-- Insertar habitaciones que existen en camas_essi pero no en habitaciones
INSERT INTO habitaciones (area_id, nombre, estado, fecha_registro, fecha_modificacion)
SELECT DISTINCT
    1 as area_id,
    ce.codhab::INT as nombre,
    true as estado,
    NOW() as fecha_registro,
    NOW() as fecha_modificacion
FROM camas_essi ce
WHERE ce.codhabcama = 'CIR1'
AND ce.codhab IS NOT NULL
AND ce.codhab != ''
AND ce.codhab ~ '^[0-9]+$'  -- Solo valores numéricos
AND NOT EXISTS (
    SELECT 1 FROM habitaciones h
    WHERE h.nombre::TEXT = ce.codhab
    AND h.area_id = 1
)
ORDER BY ce.codhab::INT;

-- Mostrar todas las habitaciones del área CIR1
DO $$
DECLARE
    rec RECORD;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE 'Habitaciones en area CIR1 (area_id=1):';
    FOR rec IN
        SELECT id, nombre
        FROM habitaciones
        WHERE area_id = 1
        ORDER BY nombre
    LOOP
        RAISE NOTICE '  ID: %, Nombre: %', rec.id, rec.nombre;
    END LOOP;
END $$;

-- =====================================================
-- 3. RESUMEN FINAL
-- =====================================================
DO $$
DECLARE
    total_dispositivos INT;
    total_habitaciones INT;
    primer_serial VARCHAR;
BEGIN
    SELECT COUNT(*) INTO total_dispositivos
    FROM esp32_dispositivos WHERE numero_serial IS NOT NULL;

    SELECT COUNT(*) INTO total_habitaciones
    FROM habitaciones WHERE area_id = 1;

    SELECT numero_serial INTO primer_serial
    FROM esp32_dispositivos
    WHERE numero_serial IS NOT NULL
    LIMIT 1;

    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'RESUMEN';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Dispositivos ESP32 validos: %', total_dispositivos;
    RAISE NOTICE 'Habitaciones en CIR1: %', total_habitaciones;
    RAISE NOTICE '';
    RAISE NOTICE 'Para crear alertas usa:';
    RAISE NOTICE '  numero_serial: %', primer_serial;
    RAISE NOTICE '  area_id: 1';
    RAISE NOTICE '========================================';
END $$;

-- Mostrar tabla de mapeo
SELECT
    h.id as habitacion_id,
    h.nombre as numero_habitacion
FROM habitaciones h
WHERE h.area_id = 1
ORDER BY h.nombre;
