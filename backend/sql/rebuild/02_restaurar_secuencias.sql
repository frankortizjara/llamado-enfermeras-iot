-- =====================================================
-- RESTAURAR SECUENCIAS DESPUES DE IMPORTAR CSVs
-- =====================================================
-- Ejecutar este script DESPUES de importar todos los CSV.
-- Esto corrige los contadores auto-increment (SERIAL)
-- para que los nuevos registros no colisionen con los
-- IDs importados.
-- =====================================================

SELECT setval('hospitales_hospital_id_seq', COALESCE((SELECT MAX(hospital_id) FROM hospitales), 0) + 1, false);
SELECT setval('usuarios_id_seq',            COALESCE((SELECT MAX(id) FROM usuarios), 0) + 1, false);
SELECT setval('esp32_dispositivos_id_seq',  COALESCE((SELECT MAX(id) FROM esp32_dispositivos), 0) + 1, false);
SELECT setval('variables_id_seq',           COALESCE((SELECT MAX(id) FROM variables), 0) + 1, false);
SELECT setval('areas_id_seq',               COALESCE((SELECT MAX(id) FROM areas), 0) + 1, false);
SELECT setval('habitaciones_id_seq',        COALESCE((SELECT MAX(id) FROM habitaciones), 0) + 1, false);
SELECT setval('camas_id_seq',               COALESCE((SELECT MAX(id) FROM camas), 0) + 1, false);
SELECT setval('asignaciones_usuarios_id_seq', COALESCE((SELECT MAX(id) FROM asignaciones_usuarios), 0) + 1, false);
SELECT setval('alertas_id_seq',             COALESCE((SELECT MAX(id) FROM alertas), 0) + 1, false);
SELECT setval('camas_essi_id_seq',          COALESCE((SELECT MAX(id) FROM camas_essi), 0) + 1, false);
SELECT setval('historial_notas_id_seq',     COALESCE((SELECT MAX(id) FROM historial_notas), 0) + 1, false);
SELECT setval('historial_alertas_id_seq',   COALESCE((SELECT MAX(id) FROM historial_alertas), 0) + 1, false);
SELECT setval('historial_ocupacion_id_seq', COALESCE((SELECT MAX(id) FROM historial_ocupacion), 0) + 1, false);

-- =====================================================
-- VERIFICACION
-- =====================================================
DO $$
DECLARE
    rec RECORD;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '================================================';
    RAISE NOTICE '  SECUENCIAS RESTAURADAS';
    RAISE NOTICE '================================================';

    FOR rec IN
        SELECT
            'hospitales' AS tabla, COUNT(*) AS registros FROM hospitales
        UNION ALL SELECT 'usuarios', COUNT(*) FROM usuarios
        UNION ALL SELECT 'areas', COUNT(*) FROM areas
        UNION ALL SELECT 'habitaciones', COUNT(*) FROM habitaciones
        UNION ALL SELECT 'camas', COUNT(*) FROM camas
        UNION ALL SELECT 'esp32_dispositivos', COUNT(*) FROM esp32_dispositivos
        UNION ALL SELECT 'variables', COUNT(*) FROM variables
        UNION ALL SELECT 'asignaciones_usuarios', COUNT(*) FROM asignaciones_usuarios
        UNION ALL SELECT 'camas_essi', COUNT(*) FROM camas_essi
        UNION ALL SELECT 'alertas', COUNT(*) FROM alertas
    LOOP
        RAISE NOTICE '  %-25s % registros', rec.tabla, rec.registros;
    END LOOP;

    RAISE NOTICE '================================================';
    RAISE NOTICE '  Base de datos lista para usar!';
    RAISE NOTICE '================================================';
    RAISE NOTICE '';
    RAISE NOTICE '  Credenciales:';
    RAISE NOTICE '    Usuario:    admin';
    RAISE NOTICE '    Password:   CAMBIA_ESTA_PASSWORD';
    RAISE NOTICE '================================================';
END $$;
