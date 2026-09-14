-- =====================================================
-- MIGRACION 41 - FASE 1: Cambio/intercambio manual de
-- cama y pagina de auditoria.
-- =====================================================
-- Pre-requisito: migracion 40 (Fase 0) aplicada.
--
-- Cambios:
--  1. Extender sp_consultar_habitaciones_essi para devolver
--     los campos de Fase 0 (origen_cambio, confirmado_por_essi,
--     fecha_alta_programada, marcado_para_eliminar, nroDocIdePac)
--  2. SP sp_cambiar_cama_paciente -- mover o intercambiar
--     pacientes entre camas (validando misma sub-area por codHabCama)
--  3. SP sp_cancelar_cambio_manual -- revertir un cambio manual
--  4. SP sp_listar_auditoria -- listado paginado con filtros
--  5. Modificar sp_cargar_data_essi -- respetar registros
--     manuales durante la ventana de gracia
-- =====================================================

SET search_path TO public;

-- =====================================================
-- PASO 1: sp_consultar_habitaciones_essi
-- Devuelve campos adicionales de Fase 0
-- =====================================================

CREATE OR REPLACE FUNCTION public.sp_consultar_habitaciones_essi(codHabCama_input VARCHAR)
RETURNS JSONB AS $$
DECLARE
    habitaciones_json JSONB := '[]'::jsonb;
    camas_json JSONB;
    habitacion RECORD;
    cama RECORD;
    ultima_sync TIMESTAMP;
BEGIN
    SELECT MAX(fecha_modificacion) INTO ultima_sync
    FROM public.camas_essi
    WHERE "codHabCama" = codHabCama_input
    AND estado = TRUE;

    FOR habitacion IN
        SELECT "codHab"
        FROM camas_essi
        WHERE "codHabCama" = codHabCama_input
        GROUP BY "codHab"
        ORDER BY "codHab"
    LOOP
        camas_json := '[]'::jsonb;
        FOR cama IN
            SELECT id, "codCama", "nroDocIdePac", "nroHisCliCas", "tipoDocIdePac",
                   "apeNomPac", nota, fecha_nota,
                   origen_cambio, confirmado_por_essi, fecha_cambio_manual,
                   fecha_alta_programada, marcado_para_eliminar, usuario_cambio_id
            FROM camas_essi c
            WHERE c."codHab" = habitacion."codHab"
              AND c."codHabCama" = codHabCama_input
              AND c.estado = TRUE
            ORDER BY "codCama"
        LOOP
            camas_json := camas_json || jsonb_build_object(
                'id', cama.id,
                'nombre', cama."codCama",
                'paciente', cama."apeNomPac",
                'nroDocIdePac', cama."nroDocIdePac",
                'nota', cama.nota,
                'fecha_nota', cama.fecha_nota,
                'origen_cambio', cama.origen_cambio,
                'confirmado_por_essi', cama.confirmado_por_essi,
                'fecha_cambio_manual', cama.fecha_cambio_manual,
                'fecha_alta_programada', cama.fecha_alta_programada,
                'marcado_para_eliminar', cama.marcado_para_eliminar,
                'usuario_cambio_id', cama.usuario_cambio_id
            );
        END LOOP;
        habitaciones_json := habitaciones_json || jsonb_build_object(
            'nombre', habitacion."codHab",
            'camas', camas_json
        );
    END LOOP;

    RETURN jsonb_build_object(
        'estado', 'success',
        'codigo', 200,
        'mensaje', jsonb_build_object(
            'habitaciones', habitaciones_json,
            'ultimaSincronizacion', COALESCE(TO_CHAR(ultima_sync, 'DD/MM/YYYY HH12:MI AM'), 'Sin datos')
        )
    );
EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object('estado', 'error', 'codigo', 500, 'mensaje', SQLERRM);
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- PASO 2: sp_cambiar_cama_paciente
-- Mueve o intercambia pacientes entre camas.
-- - Si la cama destino esta libre (sin paciente activo) -> mover
-- - Si la cama destino tiene paciente -> intercambio (swap)
-- - Solo permitido dentro de la misma sub-area (codHabCama)
-- =====================================================

DROP FUNCTION IF EXISTS public.sp_cambiar_cama_paciente(INT, INT, INT, TEXT);

CREATE OR REPLACE FUNCTION public.sp_cambiar_cama_paciente(
    pi_id_origen INT,
    pi_id_destino INT,
    pi_usuario_id INT,
    pi_motivo TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_origen RECORD;
    v_destino RECORD;
    v_es_swap BOOLEAN := FALSE;
    v_detalle TEXT;
BEGIN
    IF pi_id_origen = pi_id_destino THEN
        RETURN jsonb_build_object('estado', 'error', 'codigo', 400, 'mensaje', 'Origen y destino son la misma cama');
    END IF;

    -- Bloquear ambas filas para evitar concurrencia
    SELECT * INTO v_origen FROM public.camas_essi
    WHERE id = pi_id_origen AND estado = TRUE
    FOR UPDATE;

    IF v_origen.id IS NULL THEN
        RETURN jsonb_build_object('estado', 'error', 'codigo', 404, 'mensaje', 'Cama origen no encontrada o inactiva');
    END IF;

    SELECT * INTO v_destino FROM public.camas_essi
    WHERE id = pi_id_destino AND estado = TRUE
    FOR UPDATE;

    IF v_destino.id IS NULL THEN
        RETURN jsonb_build_object('estado', 'error', 'codigo', 404, 'mensaje', 'Cama destino no encontrada o inactiva');
    END IF;

    -- Validacion: misma sub-area (codHabCama)
    IF v_origen."codHabCama" <> v_destino."codHabCama" THEN
        RETURN jsonb_build_object('estado', 'error', 'codigo', 400,
            'mensaje', 'No se permite mover pacientes entre areas distintas');
    END IF;

    -- Validacion: el origen debe tener paciente
    IF COALESCE(v_origen."apeNomPac", '') = '' THEN
        RETURN jsonb_build_object('estado', 'error', 'codigo', 400,
            'mensaje', 'La cama origen no tiene un paciente para mover');
    END IF;

    -- Validacion: no permitir si el destino tiene alta programada o esta en rojo
    IF v_destino.fecha_alta_programada IS NOT NULL THEN
        RETURN jsonb_build_object('estado', 'error', 'codigo', 400,
            'mensaje', 'La cama destino tiene alta programada y no esta disponible');
    END IF;
    IF v_destino.marcado_para_eliminar = TRUE THEN
        RETURN jsonb_build_object('estado', 'error', 'codigo', 400,
            'mensaje', 'La cama destino tiene un paciente expirado pendiente de borrar');
    END IF;

    v_es_swap := COALESCE(v_destino."apeNomPac", '') <> '';

    IF v_es_swap THEN
        -- INTERCAMBIO: swap de datos del paciente entre origen y destino
        UPDATE public.camas_essi
        SET "apeNomPac" = v_destino."apeNomPac",
            "nroDocIdePac" = v_destino."nroDocIdePac",
            "nroHisCliCas" = v_destino."nroHisCliCas",
            "tipoDocIdePac" = v_destino."tipoDocIdePac",
            "desEstCama" = v_destino."desEstCama",
            "desSerCama" = v_destino."desSerCama",
            "diashospi" = v_destino."diashospi",
            "fechaIngreso" = v_destino."fechaIngreso",
            origen_cambio = 'MANUAL_CAMBIO_CAMA',
            usuario_cambio_id = pi_usuario_id,
            fecha_cambio_manual = CURRENT_TIMESTAMP,
            confirmado_por_essi = FALSE,
            ciclos_sync_sin_confirmar = 0,
            fecha_modificacion = CURRENT_TIMESTAMP
        WHERE id = pi_id_origen;

        UPDATE public.camas_essi
        SET "apeNomPac" = v_origen."apeNomPac",
            "nroDocIdePac" = v_origen."nroDocIdePac",
            "nroHisCliCas" = v_origen."nroHisCliCas",
            "tipoDocIdePac" = v_origen."tipoDocIdePac",
            "desEstCama" = v_origen."desEstCama",
            "desSerCama" = v_origen."desSerCama",
            "diashospi" = v_origen."diashospi",
            "fechaIngreso" = v_origen."fechaIngreso",
            origen_cambio = 'MANUAL_CAMBIO_CAMA',
            usuario_cambio_id = pi_usuario_id,
            fecha_cambio_manual = CURRENT_TIMESTAMP,
            confirmado_por_essi = FALSE,
            ciclos_sync_sin_confirmar = 0,
            fecha_modificacion = CURRENT_TIMESTAMP
        WHERE id = pi_id_destino;

        v_detalle := 'INTERCAMBIO: ' || COALESCE(v_origen."apeNomPac", '') ||
                     ' (' || v_origen."codHab" || v_origen."codCama" || ') <-> ' ||
                     COALESCE(v_destino."apeNomPac", '') ||
                     ' (' || v_destino."codHab" || v_destino."codCama" || ')' ||
                     COALESCE(' | Motivo: ' || pi_motivo, '');

        INSERT INTO public.historial_ocupacion (
            cama_essi_id, codhabcama, codhab, codcama,
            paciente, nrodocidepac, accion, usuario_id, detalle
        ) VALUES (
            pi_id_origen, v_origen."codHabCama", v_origen."codHab", v_origen."codCama",
            v_origen."apeNomPac", v_origen."nroDocIdePac", 'INTERCAMBIO_CAMA_MANUAL', pi_usuario_id, v_detalle
        ), (
            pi_id_destino, v_destino."codHabCama", v_destino."codHab", v_destino."codCama",
            v_destino."apeNomPac", v_destino."nroDocIdePac", 'INTERCAMBIO_CAMA_MANUAL', pi_usuario_id, v_detalle
        );

        RETURN jsonb_build_object('estado', 'success', 'codigo', 200,
            'mensaje', 'Pacientes intercambiados entre camas');
    ELSE
        -- MOVIMIENTO simple: origen -> destino, origen queda libre
        UPDATE public.camas_essi
        SET "apeNomPac" = v_origen."apeNomPac",
            "nroDocIdePac" = v_origen."nroDocIdePac",
            "nroHisCliCas" = v_origen."nroHisCliCas",
            "tipoDocIdePac" = v_origen."tipoDocIdePac",
            "desEstCama" = v_origen."desEstCama",
            "desSerCama" = v_origen."desSerCama",
            "diashospi" = v_origen."diashospi",
            "fechaIngreso" = v_origen."fechaIngreso",
            origen_cambio = 'MANUAL_CAMBIO_CAMA',
            usuario_cambio_id = pi_usuario_id,
            fecha_cambio_manual = CURRENT_TIMESTAMP,
            confirmado_por_essi = FALSE,
            ciclos_sync_sin_confirmar = 0,
            fecha_modificacion = CURRENT_TIMESTAMP
        WHERE id = pi_id_destino;

        UPDATE public.camas_essi
        SET "apeNomPac" = '',
            "nroDocIdePac" = '',
            "nroHisCliCas" = '',
            "tipoDocIdePac" = '',
            "desEstCama" = 'LIBRE',
            "diashospi" = '',
            "fechaIngreso" = '',
            origen_cambio = 'MANUAL_CAMBIO_CAMA',
            usuario_cambio_id = pi_usuario_id,
            fecha_cambio_manual = CURRENT_TIMESTAMP,
            confirmado_por_essi = FALSE,
            ciclos_sync_sin_confirmar = 0,
            fecha_modificacion = CURRENT_TIMESTAMP
        WHERE id = pi_id_origen;

        v_detalle := 'MOVIMIENTO: ' || v_origen."apeNomPac" ||
                     ' de ' || v_origen."codHab" || v_origen."codCama" ||
                     ' a ' || v_destino."codHab" || v_destino."codCama" ||
                     COALESCE(' | Motivo: ' || pi_motivo, '');

        INSERT INTO public.historial_ocupacion (
            cama_essi_id, codhabcama, codhab, codcama,
            paciente, nrodocidepac, accion, usuario_id, detalle
        ) VALUES (
            pi_id_destino, v_destino."codHabCama", v_destino."codHab", v_destino."codCama",
            v_origen."apeNomPac", v_origen."nroDocIdePac", 'CAMBIO_CAMA_MANUAL', pi_usuario_id, v_detalle
        );

        RETURN jsonb_build_object('estado', 'success', 'codigo', 200,
            'mensaje', 'Paciente movido de cama');
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object('estado', 'error', 'codigo', 500, 'mensaje', SQLERRM);
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- PASO 3: sp_cancelar_cambio_manual
-- Marca un cambio manual como confirmado (lo libera del
-- ciclo de gracia, asume "vuelve a confiar en EsSi").
-- No revierte datos -- la proxima sync sobrescribira si
-- EsSi dice otra cosa.
-- =====================================================

DROP FUNCTION IF EXISTS public.sp_cancelar_cambio_manual(INT, INT);

CREATE OR REPLACE FUNCTION public.sp_cancelar_cambio_manual(
    pi_id_cama INT,
    pi_usuario_id INT
)
RETURNS JSONB AS $$
DECLARE
    v_cama RECORD;
BEGIN
    SELECT * INTO v_cama FROM public.camas_essi
    WHERE id = pi_id_cama AND estado = TRUE
    FOR UPDATE;

    IF v_cama.id IS NULL THEN
        RETURN jsonb_build_object('estado', 'error', 'codigo', 404, 'mensaje', 'Cama no encontrada');
    END IF;

    IF v_cama.origen_cambio NOT LIKE 'MANUAL_%' THEN
        RETURN jsonb_build_object('estado', 'error', 'codigo', 400,
            'mensaje', 'La cama no tiene un cambio manual pendiente');
    END IF;

    UPDATE public.camas_essi
    SET origen_cambio = 'ESSI',
        confirmado_por_essi = TRUE,
        ciclos_sync_sin_confirmar = 0,
        fecha_modificacion = CURRENT_TIMESTAMP
    WHERE id = pi_id_cama;

    INSERT INTO public.historial_ocupacion (
        cama_essi_id, codhabcama, codhab, codcama,
        paciente, nrodocidepac, accion, usuario_id, detalle
    ) VALUES (
        pi_id_cama, v_cama."codHabCama", v_cama."codHab", v_cama."codCama",
        v_cama."apeNomPac", v_cama."nroDocIdePac",
        'MANUAL_CANCELADO', pi_usuario_id,
        'Cambio manual cancelado por el usuario'
    );

    RETURN jsonb_build_object('estado', 'success', 'codigo', 200,
        'mensaje', 'Cambio manual cancelado');
EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object('estado', 'error', 'codigo', 500, 'mensaje', SQLERRM);
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- PASO 4: sp_listar_auditoria
-- Listado paginado con filtros para la pagina de auditoria.
-- Devuelve { total, registros } con join a usuarios.
-- =====================================================

DROP FUNCTION IF EXISTS public.sp_listar_auditoria(TIMESTAMP, TIMESTAMP, INT, VARCHAR, INT, INT, INT);

CREATE OR REPLACE FUNCTION public.sp_listar_auditoria(
    pi_desde TIMESTAMP DEFAULT NULL,
    pi_hasta TIMESTAMP DEFAULT NULL,
    pi_usuario_id INT DEFAULT NULL,
    pi_accion VARCHAR DEFAULT NULL,
    pi_area_id INT DEFAULT NULL,
    pi_limit INT DEFAULT 50,
    pi_offset INT DEFAULT 0
)
RETURNS JSONB AS $$
DECLARE
    v_total INT;
    v_registros JSONB;
BEGIN
    -- Total para paginacion
    SELECT COUNT(*) INTO v_total
    FROM public.historial_ocupacion h
    WHERE (pi_desde IS NULL OR h.fecha_evento >= pi_desde)
      AND (pi_hasta IS NULL OR h.fecha_evento <= pi_hasta)
      AND (pi_usuario_id IS NULL OR h.usuario_id = pi_usuario_id)
      AND (pi_accion IS NULL OR h.accion = pi_accion)
      AND (pi_area_id IS NULL OR h.area_id = pi_area_id);

    -- Pagina actual
    SELECT COALESCE(jsonb_agg(row_to_json(r)::jsonb ORDER BY r.fecha_evento DESC), '[]'::jsonb)
    INTO v_registros
    FROM (
        SELECT h.id,
               h.fecha_evento,
               h.accion,
               h.codhabcama,
               h.codhab,
               h.codcama,
               h.paciente,
               h.nrodocidepac,
               h.detalle,
               h.usuario_id,
               u.nombre AS usuario_nombre,
               u.usuario AS usuario_login,
               h.area_id
        FROM public.historial_ocupacion h
        LEFT JOIN public.usuarios u ON u.id = h.usuario_id
        WHERE (pi_desde IS NULL OR h.fecha_evento >= pi_desde)
          AND (pi_hasta IS NULL OR h.fecha_evento <= pi_hasta)
          AND (pi_usuario_id IS NULL OR h.usuario_id = pi_usuario_id)
          AND (pi_accion IS NULL OR h.accion = pi_accion)
          AND (pi_area_id IS NULL OR h.area_id = pi_area_id)
        ORDER BY h.fecha_evento DESC
        LIMIT pi_limit OFFSET pi_offset
    ) r;

    RETURN jsonb_build_object(
        'estado', 'success',
        'codigo', 200,
        'mensaje', jsonb_build_object(
            'total', v_total,
            'limit', pi_limit,
            'offset', pi_offset,
            'registros', v_registros
        )
    );
EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object('estado', 'error', 'codigo', 500, 'mensaje', SQLERRM);
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- PASO 5: sp_cargar_data_essi -- respetar manuales
-- en ventana de gracia
-- =====================================================
-- Reemplaza la version de la migracion 20. La logica nueva:
-- - Si la cama tiene origen_cambio MANUAL_* y confirmado=FALSE:
--   * Si EsSi reporta el mismo DNI en la misma cama -> confirmar manual
--   * Si EsSi reporta otro DNI o libre -> NO sobrescribir.
--     Incrementar ciclos_sync_sin_confirmar.
--     Si supera VENTANA_GRACIA_CICLOS o VENTANA_GRACIA_HORAS,
--     registrar CONFLICTO_DETECTADO (la UI para resolverlo
--     entra en Fase 3).
-- - Si origen_cambio = 'ESSI' o confirmado_por_essi = TRUE:
--   * Comportamiento original (upsert).
-- =====================================================

DROP FUNCTION IF EXISTS public.sp_cargar_data_essi(VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR);

CREATE OR REPLACE FUNCTION public.sp_cargar_data_essi(
    p_apenompac VARCHAR,
    p_codhabcama VARCHAR,
    p_codhab VARCHAR,
    p_codcama VARCHAR,
    p_desestcama VARCHAR,
    p_dessercama VARCHAR,
    p_diashospi VARCHAR,
    p_fechaingreso VARCHAR,
    p_nrodocidepac VARCHAR,
    p_nrohisclicas VARCHAR,
    p_tipodocidepac VARCHAR
)
RETURNS JSONB AS $$
DECLARE
    v_existing RECORD;
    v_new_id INT;
    v_ventana_ciclos INT;
    v_ventana_horas INT;
    v_horas_desde_cambio NUMERIC;
    v_es_conflicto BOOLEAN;
BEGIN
    SELECT * INTO v_existing
    FROM public.camas_essi
    WHERE "codHabCama" = p_codhabcama
      AND "codHab" = p_codhab
      AND "codCama" = p_codcama
      AND estado = TRUE
    LIMIT 1;

    -- Caso 1: existe registro manual sin confirmar -> respetar ventana de gracia
    IF v_existing.id IS NOT NULL
       AND v_existing.origen_cambio LIKE 'MANUAL_%'
       AND v_existing.confirmado_por_essi = FALSE THEN

        -- Si EsSi confirma el cambio (mismo DNI en la misma cama)
        IF COALESCE(v_existing."nroDocIdePac", '') <> ''
           AND v_existing."nroDocIdePac" = p_nrodocidepac THEN

            UPDATE public.camas_essi
            SET confirmado_por_essi = TRUE,
                "desEstCama" = p_desestcama,
                "desSerCama" = p_dessercama,
                "diashospi" = p_diashospi,
                "fechaIngreso" = p_fechaingreso,
                fecha_modificacion = CURRENT_TIMESTAMP
            WHERE id = v_existing.id;

            INSERT INTO public.historial_ocupacion (
                cama_essi_id, codhabcama, codhab, codcama,
                paciente, nrodocidepac, accion, detalle
            ) VALUES (
                v_existing.id, p_codhabcama, p_codhab, p_codcama,
                p_apenompac, p_nrodocidepac, 'MANUAL_CONFIRMADO_POR_ESSI',
                'Sync EsSi confirmo el cambio manual'
            );

            RETURN jsonb_build_object('estado', 'success', 'codigo', 200,
                'mensaje', 'Cambio manual confirmado por EsSi');
        END IF;

        -- EsSi reporta algo distinto -> mantener manual, incrementar ciclos
        v_ventana_ciclos := COALESCE(
            (SELECT valor::INT FROM public.configuracion_sistema WHERE clave = 'VENTANA_GRACIA_CICLOS'),
            8
        );
        v_ventana_horas := COALESCE(
            (SELECT valor::INT FROM public.configuracion_sistema WHERE clave = 'VENTANA_GRACIA_HORAS'),
            4
        );

        UPDATE public.camas_essi
        SET ciclos_sync_sin_confirmar = ciclos_sync_sin_confirmar + 1,
            fecha_modificacion = CURRENT_TIMESTAMP
        WHERE id = v_existing.id;

        v_horas_desde_cambio := EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - COALESCE(v_existing.fecha_cambio_manual, v_existing.fecha_registro))) / 3600.0;
        v_es_conflicto := (v_existing.ciclos_sync_sin_confirmar + 1) >= v_ventana_ciclos
                          OR v_horas_desde_cambio >= v_ventana_horas;

        IF v_es_conflicto THEN
            -- Solo registrar la primera vez para no spammear
            IF NOT EXISTS (
                SELECT 1 FROM public.historial_ocupacion
                WHERE cama_essi_id = v_existing.id
                  AND accion = 'CONFLICTO_DETECTADO'
                  AND fecha_evento > COALESCE(v_existing.fecha_cambio_manual, v_existing.fecha_registro)
            ) THEN
                INSERT INTO public.historial_ocupacion (
                    cama_essi_id, codhabcama, codhab, codcama,
                    paciente, nrodocidepac, accion, detalle
                ) VALUES (
                    v_existing.id, p_codhabcama, p_codhab, p_codcama,
                    v_existing."apeNomPac", v_existing."nroDocIdePac",
                    'CONFLICTO_DETECTADO',
                    'EsSi reporta paciente diferente tras ventana de gracia. EsSi=' ||
                    COALESCE(p_apenompac, '(libre)') || ' DNI=' || COALESCE(p_nrodocidepac, '')
                );
            END IF;
        END IF;

        RETURN jsonb_build_object('estado', 'success', 'codigo', 200,
            'mensaje', 'Manual respetado durante ventana de gracia');
    END IF;

    -- Caso 2: comportamiento normal (sin cambios manuales pendientes)
    IF v_existing.id IS NOT NULL THEN
        IF COALESCE(v_existing."nroDocIdePac", '') = COALESCE(p_nrodocidepac, '') THEN
            UPDATE public.camas_essi
            SET "apeNomPac" = p_apenompac,
                "desEstCama" = p_desestcama,
                "desSerCama" = p_dessercama,
                "diashospi" = p_diashospi,
                "fechaIngreso" = p_fechaingreso,
                "nroHisCliCas" = p_nrohisclicas,
                "tipoDocIdePac" = p_tipodocidepac,
                fecha_modificacion = CURRENT_TIMESTAMP
            WHERE id = v_existing.id;

            RETURN jsonb_build_object('estado', 'success', 'codigo', 200, 'mensaje', 'Registro actualizado');
        ELSE
            -- Cambio de paciente en la misma cama: registrar EGRESO + INGRESO
            IF COALESCE(v_existing."apeNomPac", '') <> '' THEN
                INSERT INTO public.historial_ocupacion (
                    cama_essi_id, codhabcama, codhab, codcama,
                    paciente, nrodocidepac, accion
                ) VALUES (
                    v_existing.id, p_codhabcama, p_codhab, p_codcama,
                    v_existing."apeNomPac", v_existing."nroDocIdePac", 'EGRESO'
                );
            END IF;

            UPDATE public.camas_essi
            SET estado = FALSE,
                fecha_modificacion = CURRENT_TIMESTAMP
            WHERE id = v_existing.id;

            INSERT INTO public.camas_essi (
                "codHabCama", "codHab", "codCama", "apeNomPac",
                "desEstCama", "desSerCama", "diashospi", "fechaIngreso",
                "nroDocIdePac", "nroHisCliCas", "tipoDocIdePac",
                estado, fecha_registro, fecha_modificacion,
                origen_cambio, confirmado_por_essi
            ) VALUES (
                p_codhabcama, p_codhab, p_codcama, p_apenompac,
                p_desestcama, p_dessercama, p_diashospi, p_fechaingreso,
                p_nrodocidepac, p_nrohisclicas, p_tipodocidepac,
                TRUE, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP,
                'ESSI', TRUE
            ) RETURNING id INTO v_new_id;

            IF COALESCE(p_apenompac, '') <> '' THEN
                INSERT INTO public.historial_ocupacion (
                    cama_essi_id, codhabcama, codhab, codcama,
                    paciente, nrodocidepac, accion
                ) VALUES (
                    v_new_id, p_codhabcama, p_codhab, p_codcama,
                    p_apenompac, p_nrodocidepac, 'INGRESO'
                );
            END IF;

            RETURN jsonb_build_object('estado', 'success', 'codigo', 200, 'mensaje', 'Paciente cambiado en cama');
        END IF;
    ELSE
        INSERT INTO public.camas_essi (
            "codHabCama", "codHab", "codCama", "apeNomPac",
            "desEstCama", "desSerCama", "diashospi", "fechaIngreso",
            "nroDocIdePac", "nroHisCliCas", "tipoDocIdePac",
            estado, fecha_registro, fecha_modificacion,
            origen_cambio, confirmado_por_essi
        ) VALUES (
            p_codhabcama, p_codhab, p_codcama, p_apenompac,
            p_desestcama, p_dessercama, p_diashospi, p_fechaingreso,
            p_nrodocidepac, p_nrohisclicas, p_tipodocidepac,
            TRUE, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP,
            'ESSI', TRUE
        ) RETURNING id INTO v_new_id;

        IF COALESCE(p_apenompac, '') <> '' THEN
            INSERT INTO public.historial_ocupacion (
                cama_essi_id, codhabcama, codhab, codcama,
                paciente, nrodocidepac, accion
            ) VALUES (
                v_new_id, p_codhabcama, p_codhab, p_codcama,
                p_apenompac, p_nrodocidepac, 'INGRESO'
            );
        END IF;

        RETURN jsonb_build_object('estado', 'success', 'codigo', 200, 'mensaje', 'Registro insertado exitosamente');
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object('estado', 'error', 'codigo', 500, 'mensaje', SQLERRM);
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- PASO 6: Verificacion
-- =====================================================

DO $$
BEGIN
    RAISE NOTICE 'Migracion 41 (Fase 1) aplicada. SPs creados:';
    RAISE NOTICE '  - sp_consultar_habitaciones_essi (extendido con campos Fase 0)';
    RAISE NOTICE '  - sp_cambiar_cama_paciente (mover/intercambiar pacientes)';
    RAISE NOTICE '  - sp_cancelar_cambio_manual';
    RAISE NOTICE '  - sp_listar_auditoria (paginado con filtros)';
    RAISE NOTICE '  - sp_cargar_data_essi (respeta ventana de gracia)';
END $$;
