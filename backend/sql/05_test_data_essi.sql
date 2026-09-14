-- =====================================================
-- SCRIPT DE DATOS DE PRUEBA ESSI - Sistema Llamado Enfermeras
-- =====================================================
-- Este script crea datos ficticios en la tabla camas_essi
-- para probar el sistema sin conexión a la API EsSi externa
-- =====================================================
-- La tabla camas_essi almacena datos de pacientes que
-- normalmente se obtienen de la API externa de EsSalud
-- =====================================================

-- Limpiar datos de prueba anteriores (opcional)
-- DELETE FROM camas_essi WHERE "codHabCama" = 'UCI';

-- =====================================================
-- INSERTAR DATOS DE PRUEBA PARA UCI
-- =====================================================
-- codHabCama = nombre del área (UCI, EMERGENCIA, etc.)
-- codHab = número de habitación
-- codCama = letra de cama (A, B, C, etc.)

INSERT INTO camas_essi (
    codhabcama, codhab, codcama, apenompac, desestcama,
    dessercama, diashospi, fechaingreso, nrodocidepac,
    nrohisclicas, tipodocidepac, nota, fecha_nota, estado
) VALUES
-- Habitación 101
('UCI', '101', 'A', 'GARCIA LOPEZ, MARIA ELENA', 'OCUPADA', 'UCI ADULTOS', '5', '2025-01-17', '12345678', 'HC-001234', 'DNI', '', '', true),
('UCI', '101', 'B', 'RODRIGUEZ PEREZ, JUAN CARLOS', 'OCUPADA', 'UCI ADULTOS', '3', '2025-01-19', '87654321', 'HC-001235', 'DNI', '', '', true),
('UCI', '101', 'C', 'Baño', 'SERVICIO', 'UCI ADULTOS', '', '', '', '', '', '', '', true),

-- Habitación 102
('UCI', '102', 'A', 'MARTINEZ SANCHEZ, ANA LUCIA', 'OCUPADA', 'UCI ADULTOS', '7', '2025-01-15', '11223344', 'HC-001236', 'DNI', '', '', true),
('UCI', '102', 'B', 'FERNANDEZ DIAZ, PEDRO MIGUEL', 'OCUPADA', 'UCI ADULTOS', '2', '2025-01-20', '55667788', 'HC-001237', 'DNI', '', '', true),
('UCI', '102', 'C', 'TORRES RUIZ, CARMEN ROSA', 'OCUPADA', 'UCI ADULTOS', '4', '2025-01-18', '99001122', 'HC-001238', 'DNI', '', '', true),

-- Habitación 103
('UCI', '103', 'A', 'LOPEZ VARGAS, ROBERTO LUIS', 'OCUPADA', 'UCI ADULTOS', '6', '2025-01-16', '33445566', 'HC-001239', 'DNI', '', '', true),
('UCI', '103', 'B', 'CASTRO MENDOZA, SOFIA MARIA', 'OCUPADA', 'UCI ADULTOS', '1', '2025-01-21', '77889900', 'HC-001240', 'DNI', '', '', true),

-- Habitación 104
('UCI', '104', 'A', 'RAMIREZ FLORES, JOSE ANTONIO', 'OCUPADA', 'UCI ADULTOS', '8', '2025-01-14', '22334455', 'HC-001241', 'DNI', '', '', true),
('UCI', '104', 'B', 'Baño', 'SERVICIO', 'UCI ADULTOS', '', '', '', '', '', '', '', true),
('UCI', '104', 'C', 'MORALES CRUZ, LUCIA PATRICIA', 'OCUPADA', 'UCI ADULTOS', '3', '2025-01-19', '66778899', 'HC-001242', 'DNI', '', '', true),

-- Habitación 105
('UCI', '105', 'A', 'HERNANDEZ VEGA, CARLOS EDUARDO', 'OCUPADA', 'UCI ADULTOS', '5', '2025-01-17', '44556677', 'HC-001243', 'DNI', '', '', true),
('UCI', '105', 'B', 'SILVA TORRES, MARIA FERNANDA', 'OCUPADA', 'UCI ADULTOS', '2', '2025-01-20', '88990011', 'HC-001244', 'DNI', '', '', true)

ON CONFLICT DO NOTHING;

-- =====================================================
-- VERIFICAR DATOS CREADOS
-- =====================================================
DO $$
DECLARE
    v_count INT;
BEGIN
    SELECT COUNT(*) INTO v_count FROM camas_essi WHERE codhabcama = 'UCI' AND estado = true;

    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'DATOS DE PRUEBA ESSI INSERTADOS';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Total camas en UCI: %', v_count;
    RAISE NOTICE '';
    RAISE NOTICE 'Habitaciones creadas:';
    RAISE NOTICE '  101 - 3 camas (2 pacientes + baño)';
    RAISE NOTICE '  102 - 3 camas (3 pacientes)';
    RAISE NOTICE '  103 - 2 camas (2 pacientes)';
    RAISE NOTICE '  104 - 3 camas (2 pacientes + baño)';
    RAISE NOTICE '  105 - 2 camas (2 pacientes)';
    RAISE NOTICE '========================================';
    RAISE NOTICE '';
    RAISE NOTICE 'Ahora recarga la pagina del frontend';
    RAISE NOTICE '========================================';
END $$;

-- Mostrar resumen de datos
SELECT codhab as habitacion, COUNT(*) as camas
FROM camas_essi
WHERE codhabcama = 'UCI' AND estado = true
GROUP BY codhab
ORDER BY codhab;
