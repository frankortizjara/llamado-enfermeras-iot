-- =====================================================
-- MIGRACION 40 - FASE 0: Infraestructura comun para
-- gestion manual de camas y pacientes
-- =====================================================
-- Cambios:
--  1. Tabla configuracion_sistema (clave/valor) para
--     parametros editables en runtime (ej: SYNC_INTERVAL_MINUTES)
--  2. Tabla pacientes (DNI como dato permanente)
--  3. Columnas adicionales en camas_essi para distinguir
--     origen del cambio (ESSI vs MANUAL_*) y soportar
--     ventana de gracia, alta programada, marcado en rojo
--  4. Columnas adicionales en historial_ocupacion
--     (usuario_id, detalle) y nuevas acciones permitidas
--  5. SPs para gestionar configuracion_sistema
--
-- IMPORTANTE: Esta migracion NO modifica el comportamiento
-- visible. Solo prepara la base para Fases 1-3.
-- =====================================================

SET search_path TO public;

-- =====================================================
-- PASO 1: Tabla configuracion_sistema
-- =====================================================

CREATE TABLE IF NOT EXISTS public.configuracion_sistema (
    clave VARCHAR(100) PRIMARY KEY,
    valor VARCHAR(255) NOT NULL,
    descripcion TEXT,
    tipo VARCHAR(20) NOT NULL DEFAULT 'STRING',  -- INT, DECIMAL, BOOLEAN, STRING
    valor_min VARCHAR(50),
    valor_max VARCHAR(50),
    fecha_modificacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    usuario_modifico_id INT REFERENCES public.usuarios(id) ON DELETE SET NULL
);

COMMENT ON TABLE public.configuracion_sistema IS 'Parametros del sistema editables en runtime sin reiniciar';

-- Datos iniciales (idempotente con ON CONFLICT)
INSERT INTO public.configuracion_sistema (clave, valor, descripcion, tipo, valor_min, valor_max)
VALUES
    ('SYNC_INTERVAL_MINUTES', '30',
     'Cada cuantos minutos sincroniza con la API EsSi', 'INT', '1', '1440'),
    ('VENTANA_GRACIA_HORAS', '4',
     'Horas que un cambio manual sobrevive sin confirmacion de EsSi antes de marcarse como conflicto', 'INT', '1', '72'),
    ('VENTANA_GRACIA_CICLOS', '8',
     'Ciclos de sync que un cambio manual sobrevive sin confirmacion (la primera ventana que se cumpla aplica)', 'INT', '1', '100'),
    ('TIEMPO_ROJO_HASTA_ELIMINAR_HORAS', '2',
     'Horas que un paciente manual marcado en rojo persiste antes de borrarse (estado=FALSE)', 'INT', '1', '72')
ON CONFLICT (clave) DO NOTHING;

-- =====================================================
-- PASO 2: Tabla pacientes (DNI como dato permanente)
-- =====================================================

CREATE TABLE IF NOT EXISTS public.pacientes (
    id SERIAL PRIMARY KEY,
    nro_doc_ide_pac VARCHAR(20) UNIQUE NOT NULL,
    tipo_doc_ide_pac VARCHAR(10) DEFAULT 'DNI',
    ape_nom_pac VARCHAR(255) NOT NULL,
    nro_his_cli_cas VARCHAR(50),
    fecha_registro TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    fecha_modificacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_pacientes_dni ON public.pacientes(nro_doc_ide_pac);

COMMENT ON TABLE public.pacientes IS 'Catalogo permanente de pacientes (DNI). Se popula desde sync EsSi y desde ingresos manuales.';

-- =====================================================
-- PASO 3: Extender camas_essi con columnas de Fase 0
-- =====================================================
-- Todas son nullable y con default seguro para mantener
-- compatibilidad con datos antiguos. origen_cambio default
-- 'ESSI' para que registros existentes se traten como
-- automaticos.
-- =====================================================

ALTER TABLE public.camas_essi
    ADD COLUMN IF NOT EXISTS origen_cambio VARCHAR(30) NOT NULL DEFAULT 'ESSI',
    ADD COLUMN IF NOT EXISTS usuario_cambio_id INT REFERENCES public.usuarios(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS fecha_cambio_manual TIMESTAMP,
    ADD COLUMN IF NOT EXISTS fecha_alta_programada TIMESTAMP,
    ADD COLUMN IF NOT EXISTS fecha_salida_obligatoria TIMESTAMP,
    ADD COLUMN IF NOT EXISTS confirmado_por_essi BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS marcado_para_eliminar BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS fecha_marcado_eliminar TIMESTAMP,
    ADD COLUMN IF NOT EXISTS ciclos_sync_sin_confirmar INT NOT NULL DEFAULT 0;

-- Indices para consultas del cron secundario
CREATE INDEX IF NOT EXISTS idx_camas_essi_origen_cambio
    ON public.camas_essi(origen_cambio)
    WHERE origen_cambio <> 'ESSI';

CREATE INDEX IF NOT EXISTS idx_camas_essi_marcado_para_eliminar
    ON public.camas_essi(marcado_para_eliminar, fecha_marcado_eliminar)
    WHERE marcado_para_eliminar = TRUE;

CREATE INDEX IF NOT EXISTS idx_camas_essi_alta_programada
    ON public.camas_essi(fecha_alta_programada)
    WHERE fecha_alta_programada IS NOT NULL;

-- Validar que origen_cambio toma solo valores conocidos
ALTER TABLE public.camas_essi
    DROP CONSTRAINT IF EXISTS chk_camas_essi_origen_cambio;
ALTER TABLE public.camas_essi
    ADD CONSTRAINT chk_camas_essi_origen_cambio
    CHECK (origen_cambio IN (
        'ESSI',
        'MANUAL_INGRESO',
        'MANUAL_CAMBIO_CAMA',
        'MANUAL_ALTA_PROGRAMADA',
        'MANUAL_RESERVA'
    ));

-- =====================================================
-- PASO 4: Extender historial_ocupacion
-- =====================================================
-- Agrega usuario_id (quien hizo el cambio) y detalle
-- (texto libre para motivo, contexto, datos viejos/nuevos).
-- =====================================================

ALTER TABLE public.historial_ocupacion
    ADD COLUMN IF NOT EXISTS usuario_id INT REFERENCES public.usuarios(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS detalle TEXT,
    ADD COLUMN IF NOT EXISTS area_id INT REFERENCES public.areas(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_historial_ocupacion_usuario
    ON public.historial_ocupacion(usuario_id);
CREATE INDEX IF NOT EXISTS idx_historial_ocupacion_accion
    ON public.historial_ocupacion(accion);
CREATE INDEX IF NOT EXISTS idx_historial_ocupacion_area
    ON public.historial_ocupacion(area_id);

-- Ampliar el largo de accion (las nuevas acciones llegan a 32 caracteres)
ALTER TABLE public.historial_ocupacion
    ALTER COLUMN accion TYPE VARCHAR(40);

-- =====================================================
-- PASO 5: SPs para configuracion_sistema
-- =====================================================

DROP FUNCTION IF EXISTS public.sp_obtener_configuracion(VARCHAR);
DROP FUNCTION IF EXISTS public.sp_listar_configuracion();
DROP FUNCTION IF EXISTS public.sp_actualizar_configuracion(VARCHAR, VARCHAR, INT);

CREATE OR REPLACE FUNCTION public.sp_listar_configuracion()
RETURNS JSONB AS $$
DECLARE
    v_resultado JSONB;
BEGIN
    SELECT COALESCE(jsonb_agg(row_to_json(c)::jsonb ORDER BY c.clave), '[]'::jsonb)
    INTO v_resultado
    FROM (
        SELECT clave, valor, descripcion, tipo, valor_min, valor_max,
               fecha_modificacion, usuario_modifico_id
        FROM public.configuracion_sistema
    ) c;

    RETURN jsonb_build_object('estado', 'success', 'codigo', 200, 'mensaje', v_resultado);
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('estado', 'error', 'codigo', 500, 'mensaje', SQLERRM);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION public.sp_obtener_configuracion(pi_clave VARCHAR)
RETURNS JSONB AS $$
DECLARE
    v_row JSONB;
BEGIN
    SELECT to_jsonb(c) INTO v_row
    FROM (
        SELECT clave, valor, descripcion, tipo, valor_min, valor_max,
               fecha_modificacion, usuario_modifico_id
        FROM public.configuracion_sistema
        WHERE clave = pi_clave
    ) c;

    IF v_row IS NULL THEN
        RETURN jsonb_build_object('estado', 'error', 'codigo', 404, 'mensaje', 'Clave no encontrada');
    END IF;

    RETURN jsonb_build_object('estado', 'success', 'codigo', 200, 'mensaje', v_row);
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('estado', 'error', 'codigo', 500, 'mensaje', SQLERRM);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION public.sp_actualizar_configuracion(
    pi_clave VARCHAR,
    pi_valor VARCHAR,
    pi_usuario_id INT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_existente RECORD;
    v_valor_int INT;
    v_min_int INT;
    v_max_int INT;
BEGIN
    -- Verificar que la clave existe (no se permite crear claves arbitrarias desde la UI)
    SELECT clave, tipo, valor_min, valor_max
    INTO v_existente
    FROM public.configuracion_sistema
    WHERE clave = pi_clave;

    IF v_existente.clave IS NULL THEN
        RETURN jsonb_build_object('estado', 'error', 'codigo', 404, 'mensaje', 'Clave no encontrada');
    END IF;

    -- Validar segun tipo
    IF v_existente.tipo = 'INT' THEN
        BEGIN
            v_valor_int := pi_valor::INT;
        EXCEPTION WHEN OTHERS THEN
            RETURN jsonb_build_object('estado', 'error', 'codigo', 400, 'mensaje', 'El valor debe ser un entero');
        END;

        IF v_existente.valor_min IS NOT NULL THEN
            v_min_int := v_existente.valor_min::INT;
            IF v_valor_int < v_min_int THEN
                RETURN jsonb_build_object('estado', 'error', 'codigo', 400,
                    'mensaje', 'Valor menor al permitido (min ' || v_min_int || ')');
            END IF;
        END IF;
        IF v_existente.valor_max IS NOT NULL THEN
            v_max_int := v_existente.valor_max::INT;
            IF v_valor_int > v_max_int THEN
                RETURN jsonb_build_object('estado', 'error', 'codigo', 400,
                    'mensaje', 'Valor mayor al permitido (max ' || v_max_int || ')');
            END IF;
        END IF;
    ELSIF v_existente.tipo = 'BOOLEAN' THEN
        IF lower(pi_valor) NOT IN ('true', 'false') THEN
            RETURN jsonb_build_object('estado', 'error', 'codigo', 400, 'mensaje', 'El valor debe ser true o false');
        END IF;
    END IF;

    UPDATE public.configuracion_sistema
    SET valor = pi_valor,
        fecha_modificacion = CURRENT_TIMESTAMP,
        usuario_modifico_id = pi_usuario_id
    WHERE clave = pi_clave;

    -- Auditar el cambio en historial_ocupacion (es nuestra tabla de auditoria general)
    INSERT INTO public.historial_ocupacion (
        cama_essi_id, codhabcama, codhab, codcama,
        paciente, nrodocidepac, accion, usuario_id, detalle
    ) VALUES (
        NULL, NULL, NULL, NULL,
        NULL, NULL, 'CONFIG_MODIFICADA', pi_usuario_id,
        'Clave=' || pi_clave || ', Valor=' || pi_valor
    );

    RETURN jsonb_build_object('estado', 'success', 'codigo', 200, 'mensaje', 'Configuracion actualizada');
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('estado', 'error', 'codigo', 500, 'mensaje', SQLERRM);
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- PASO 6: Verificacion
-- =====================================================

DO $$
DECLARE
    v_count INT;
BEGIN
    SELECT COUNT(*) INTO v_count FROM public.configuracion_sistema;
    RAISE NOTICE 'Migracion 40 (Fase 0) aplicada. configuracion_sistema tiene % filas.', v_count;

    SELECT COUNT(*) INTO v_count
    FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'camas_essi'
      AND column_name IN (
        'origen_cambio', 'usuario_cambio_id', 'fecha_cambio_manual',
        'fecha_alta_programada', 'fecha_salida_obligatoria',
        'confirmado_por_essi', 'marcado_para_eliminar',
        'fecha_marcado_eliminar', 'ciclos_sync_sin_confirmar'
      );
    IF v_count <> 9 THEN
        RAISE EXCEPTION 'camas_essi no tiene las 9 columnas de Fase 0 (encontradas: %)', v_count;
    END IF;

    SELECT COUNT(*) INTO v_count
    FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name IN ('pacientes', 'configuracion_sistema');
    IF v_count <> 2 THEN
        RAISE EXCEPTION 'Faltan tablas (pacientes/configuracion_sistema). Encontradas: %', v_count;
    END IF;

    RAISE NOTICE 'OK - Fase 0 lista. Ahora se debe redeployar el backend para que lea la config desde BD.';
END $$;
