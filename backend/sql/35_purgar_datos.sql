-- =====================================================
-- MIGRACION 35: Stored procedures para purgar datos
-- =====================================================
-- 3 SPs para eliminar datos que generan conflicto:
--   1. sp_purgar_eventos_dispositivos - Borra eventos de conexion/desconexion
--   2. sp_purgar_dispositivos_esp32 - Borra registros de dispositivos ESP32
--   3. sp_purgar_analytics - Borra datos de analytics (alertas, notas, ocupacion)
-- =====================================================

SET search_path TO public;

-- =====================================================
-- 1. Purgar eventos de dispositivos (conexion/desconexion)
-- =====================================================

CREATE OR REPLACE FUNCTION public.sp_purgar_eventos_dispositivos()
RETURNS JSONB AS $$
DECLARE
    filas_eliminadas INTEGER;
BEGIN
    BEGIN
        DELETE FROM public.dispositivo_eventos;
        GET DIAGNOSTICS filas_eliminadas = ROW_COUNT;

        RETURN jsonb_build_object(
            'estado', 'success',
            'codigo', 200,
            'mensaje', 'Se eliminaron ' || filas_eliminadas || ' eventos de dispositivos'
        );
    EXCEPTION
        WHEN OTHERS THEN
            RETURN jsonb_build_object('estado', 'error', 'codigo', 500, 'mensaje', SQLERRM);
    END;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- 2. Purgar dispositivos ESP32 (registro completo)
-- =====================================================

CREATE OR REPLACE FUNCTION public.sp_purgar_dispositivos_esp32()
RETURNS JSONB AS $$
DECLARE
    eventos_eliminados INTEGER;
    dispositivos_eliminados INTEGER;
BEGIN
    BEGIN
        -- Primero eliminar eventos relacionados
        DELETE FROM public.dispositivo_eventos;
        GET DIAGNOSTICS eventos_eliminados = ROW_COUNT;

        -- Luego eliminar dispositivos
        DELETE FROM public.esp32_dispositivos;
        GET DIAGNOSTICS dispositivos_eliminados = ROW_COUNT;

        RETURN jsonb_build_object(
            'estado', 'success',
            'codigo', 200,
            'mensaje', 'Se eliminaron ' || dispositivos_eliminados || ' dispositivos y ' || eventos_eliminados || ' eventos'
        );
    EXCEPTION
        WHEN OTHERS THEN
            RETURN jsonb_build_object('estado', 'error', 'codigo', 500, 'mensaje', SQLERRM);
    END;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- 3. Purgar datos de analytics por area
-- =====================================================

CREATE OR REPLACE FUNCTION public.sp_purgar_analytics(
    pi_area_id INT
)
RETURNS JSONB AS $$
DECLARE
    alertas_eliminadas INTEGER;
    notas_eliminadas INTEGER;
    ocupacion_eliminada INTEGER;
    v_area_nombre VARCHAR(255);
BEGIN
    BEGIN
        -- Obtener nombre del area para filtrar historial_notas y ocupacion
        SELECT nombre INTO v_area_nombre
        FROM public.areas
        WHERE id = pi_area_id;

        IF v_area_nombre IS NULL THEN
            RETURN jsonb_build_object('estado', 'error', 'codigo', 404, 'mensaje', 'Area no encontrada');
        END IF;

        -- Eliminar historial de alertas del area
        DELETE FROM public.historial_alertas WHERE area_id = pi_area_id;
        GET DIAGNOSTICS alertas_eliminadas = ROW_COUNT;

        -- Eliminar historial de notas del area
        DELETE FROM public.historial_notas WHERE codhabcama = v_area_nombre;
        GET DIAGNOSTICS notas_eliminadas = ROW_COUNT;

        -- Eliminar historial de ocupacion del area
        DELETE FROM public.historial_ocupacion WHERE codhabcama = v_area_nombre;
        GET DIAGNOSTICS ocupacion_eliminada = ROW_COUNT;

        RETURN jsonb_build_object(
            'estado', 'success',
            'codigo', 200,
            'mensaje', 'Se eliminaron ' || alertas_eliminadas || ' alertas, ' || notas_eliminadas || ' notas y ' || ocupacion_eliminada || ' registros de ocupacion'
        );
    EXCEPTION
        WHEN OTHERS THEN
            RETURN jsonb_build_object('estado', 'error', 'codigo', 500, 'mensaje', SQLERRM);
    END;
END;
$$ LANGUAGE plpgsql;

-- Verificacion
DO $$
BEGIN
    RAISE NOTICE 'Migracion 35: 3 SPs de purga de datos creados';
    RAISE NOTICE '  - sp_purgar_eventos_dispositivos';
    RAISE NOTICE '  - sp_purgar_dispositivos_esp32';
    RAISE NOTICE '  - sp_purgar_analytics';
END $$;
