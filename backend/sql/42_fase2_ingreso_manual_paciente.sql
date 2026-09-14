-- =====================================================
-- MIGRACION 42 - FASE 2: Ingreso manual de paciente
-- + cron secundario (marcado rojo / borrado a 2h)
-- =====================================================
-- Pre-requisito: migracion 41 (Fase 1) aplicada.
--
-- Cambios:
--  1. SP sp_ingresar_paciente_manual -- inserta paciente
--     en cama LIBRE con DNI obligatorio y fecha de salida
--     obligatoria. Upsert en tabla pacientes por DNI.
--  2. SP sp_buscar_paciente_por_dni -- para autocompletar
--     desde la UI cuando el DNI ya existe.
--  3. SP sp_procesar_manuales_expirados -- ejecutado por
--     cron cada 1 min:
--       a) Marca en rojo manuales con fecha_salida_obligatoria
--          vencida y aun sin confirmar por EsSi.
--       b) Borra (estado=FALSE) los que llevan
--          TIEMPO_ROJO_HASTA_ELIMINAR_HORAS en rojo.
-- =====================================================

SET search_path TO public;

-- =====================================================
-- PASO 1: sp_buscar_paciente_por_dni
-- =====================================================

DROP FUNCTION IF EXISTS public.sp_buscar_paciente_por_dni(VARCHAR);

CREATE OR REPLACE FUNCTION public.sp_buscar_paciente_por_dni(pi_dni VARCHAR)
RETURNS JSONB AS $$
DECLARE
    v_paciente JSONB;
BEGIN
    SELECT to_jsonb(p) INTO v_paciente
    FROM (
        SELECT id, nro_doc_ide_pac, tipo_doc_ide_pac, ape_nom_pac, nro_his_cli_cas,
               fecha_registro, fecha_modificacion
        FROM public.pacientes
        WHERE nro_doc_ide_pac = pi_dni
        LIMIT 1
    ) p;

    IF v_paciente IS NULL THEN
        RETURN jsonb_build_object('estado', 'success', 'codigo', 404, 'mensaje', NULL);
    END IF;

    RETURN jsonb_build_object('estado', 'success', 'codigo', 200, 'mensaje', v_paciente);
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('estado', 'error', 'codigo', 500, 'mensaje', SQLERRM);
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- PASO 2: sp_ingresar_paciente_manual
-- =====================================================
-- Reglas:
-- - La cama destino debe existir y estar activa.
-- - La cama destino debe estar LIBRE (apeNomPac vacio).
-- - DNI es obligatorio (validado en backend tambien).
-- - fecha_salida_obligatoria es obligatoria.
-- - Si el DNI ya existe en `pacientes`, se actualizan
--   nombre/historia (sirve para casos de cambio de apellidos).
-- - Se inserta/upsert en `pacientes`.
-- - Se actualiza el registro de `camas_essi` con los datos
--   del paciente y origen_cambio='MANUAL_INGRESO'.
-- =====================================================

DROP FUNCTION IF EXISTS public.sp_ingresar_paciente_manual(INT, VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR, TIMESTAMP, BOOLEAN, INT, TEXT);

CREATE OR REPLACE FUNCTION public.sp_ingresar_paciente_manual(
    pi_id_cama INT,
    pi_nro_doc_ide_pac VARCHAR,
    pi_tipo_doc_ide_pac VARCHAR,
    pi_ape_nom_pac VARCHAR,
    pi_nro_his_cli_cas VARCHAR,
    pi_des_ser_cama VARCHAR,
    pi_fecha_salida_obligatoria TIMESTAMP,
    pi_pertenece_al_area BOOLEAN,
    pi_usuario_id INT,
    pi_motivo TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_cama RECORD;
    v_fecha_ingreso_str VARCHAR;
    v_detalle TEXT;
BEGIN
    -- Validar entradas minimas
    IF COALESCE(TRIM(pi_nro_doc_ide_pac), '') = '' THEN
        RETURN jsonb_build_object('estado', 'error', 'codigo', 400, 'mensaje', 'DNI es obligatorio');
    END IF;
    IF COALESCE(TRIM(pi_ape_nom_pac), '') = '' THEN
        RETURN jsonb_build_object('estado', 'error', 'codigo', 400, 'mensaje', 'Apellido/nombre del paciente es obligatorio');
    END IF;
    IF pi_fecha_salida_obligatoria IS NULL THEN
        RETURN jsonb_build_object('estado', 'error', 'codigo', 400, 'mensaje', 'Fecha de salida obligatoria es requerida');
    END IF;
    IF pi_fecha_salida_obligatoria <= CURRENT_TIMESTAMP THEN
        RETURN jsonb_build_object('estado', 'error', 'codigo', 400, 'mensaje', 'Fecha de salida obligatoria debe ser futura');
    END IF;

    -- Bloquear la cama destino para evitar concurrencia
    SELECT * INTO v_cama FROM public.camas_essi
    WHERE id = pi_id_cama AND estado = TRUE
    FOR UPDATE;

    IF v_cama.id IS NULL THEN
        RETURN jsonb_build_object('estado', 'error', 'codigo', 404, 'mensaje', 'Cama no encontrada o inactiva');
    END IF;

    IF COALESCE(v_cama."apeNomPac", '') <> '' THEN
        RETURN jsonb_build_object('estado', 'error', 'codigo', 400,
            'mensaje', 'La cama ya tiene un paciente. Para reemplazar, primero libere la cama o use cambio de cama');
    END IF;

    IF v_cama.fecha_alta_programada IS NOT NULL THEN
        RETURN jsonb_build_object('estado', 'error', 'codigo', 400,
            'mensaje', 'La cama tiene alta programada y no esta disponible para ingreso manual');
    END IF;

    -- Upsert en tabla pacientes
    INSERT INTO public.pacientes (
        nro_doc_ide_pac, tipo_doc_ide_pac, ape_nom_pac, nro_his_cli_cas
    ) VALUES (
        TRIM(pi_nro_doc_ide_pac), COALESCE(pi_tipo_doc_ide_pac, 'DNI'),
        TRIM(pi_ape_nom_pac), pi_nro_his_cli_cas
    )
    ON CONFLICT (nro_doc_ide_pac) DO UPDATE
        SET ape_nom_pac = EXCLUDED.ape_nom_pac,
            tipo_doc_ide_pac = COALESCE(EXCLUDED.tipo_doc_ide_pac, public.pacientes.tipo_doc_ide_pac),
            nro_his_cli_cas = COALESCE(EXCLUDED.nro_his_cli_cas, public.pacientes.nro_his_cli_cas),
            fecha_modificacion = CURRENT_TIMESTAMP;

    -- Datos de la cama (actualizar registro existente)
    v_fecha_ingreso_str := TO_CHAR(CURRENT_TIMESTAMP, 'DD/MM/YYYY');

    UPDATE public.camas_essi
    SET "apeNomPac" = TRIM(pi_ape_nom_pac),
        "nroDocIdePac" = TRIM(pi_nro_doc_ide_pac),
        "tipoDocIdePac" = COALESCE(pi_tipo_doc_ide_pac, 'DNI'),
        "nroHisCliCas" = COALESCE(pi_nro_his_cli_cas, ''),
        "desEstCama" = 'OCUPADA',
        "desSerCama" = COALESCE(pi_des_ser_cama, v_cama."desSerCama"),
        "diashospi" = '0',
        "fechaIngreso" = v_fecha_ingreso_str,
        origen_cambio = 'MANUAL_INGRESO',
        usuario_cambio_id = pi_usuario_id,
        fecha_cambio_manual = CURRENT_TIMESTAMP,
        confirmado_por_essi = FALSE,
        ciclos_sync_sin_confirmar = 0,
        fecha_salida_obligatoria = pi_fecha_salida_obligatoria,
        marcado_para_eliminar = FALSE,
        fecha_marcado_eliminar = NULL,
        fecha_modificacion = CURRENT_TIMESTAMP
    WHERE id = pi_id_cama;

    v_detalle := 'INGRESO_MANUAL: ' || TRIM(pi_ape_nom_pac) ||
                 ' (DNI=' || TRIM(pi_nro_doc_ide_pac) || ')' ||
                 ' en ' || v_cama."codHab" || v_cama."codCama" ||
                 ' | Salida obligatoria: ' || TO_CHAR(pi_fecha_salida_obligatoria, 'DD/MM/YYYY HH24:MI') ||
                 ' | ' || CASE WHEN pi_pertenece_al_area THEN 'pertenece al area' ELSE 'viene de otra area' END ||
                 COALESCE(' | Motivo: ' || pi_motivo, '');

    INSERT INTO public.historial_ocupacion (
        cama_essi_id, codhabcama, codhab, codcama,
        paciente, nrodocidepac, accion, usuario_id, detalle
    ) VALUES (
        pi_id_cama, v_cama."codHabCama", v_cama."codHab", v_cama."codCama",
        TRIM(pi_ape_nom_pac), TRIM(pi_nro_doc_ide_pac),
        'INGRESO_MANUAL', pi_usuario_id, v_detalle
    );

    RETURN jsonb_build_object('estado', 'success', 'codigo', 200,
        'mensaje', 'Paciente ingresado manualmente');
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('estado', 'error', 'codigo', 500, 'mensaje', SQLERRM);
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- PASO 3: sp_procesar_manuales_expirados
-- =====================================================
-- Llamado por cron cada 1 minuto. Hace dos cosas en orden:
--   1) Marca rojo: manuales pendientes (confirmado=FALSE)
--      cuya fecha_salida_obligatoria ya paso.
--   2) Borra (estado=FALSE) los que llevan en rojo mas
--      del tiempo configurado.
-- Devuelve cantidad de cada accion.
-- =====================================================

DROP FUNCTION IF EXISTS public.sp_procesar_manuales_expirados();

CREATE OR REPLACE FUNCTION public.sp_procesar_manuales_expirados()
RETURNS JSONB AS $$
DECLARE
    v_tiempo_rojo_h INT;
    v_marcados INT := 0;
    v_eliminados INT := 0;
    v_row RECORD;
BEGIN
    v_tiempo_rojo_h := COALESCE(
        (SELECT valor::INT FROM public.configuracion_sistema
         WHERE clave = 'TIEMPO_ROJO_HASTA_ELIMINAR_HORAS'),
        2
    );

    -- 1) Marcar en rojo los que vencieron sin confirmacion EsSi
    FOR v_row IN
        SELECT id, "codHabCama", "codHab", "codCama", "apeNomPac", "nroDocIdePac",
               usuario_cambio_id, fecha_salida_obligatoria
        FROM public.camas_essi
        WHERE estado = TRUE
          AND origen_cambio LIKE 'MANUAL_%'
          AND confirmado_por_essi = FALSE
          AND marcado_para_eliminar = FALSE
          AND fecha_salida_obligatoria IS NOT NULL
          AND fecha_salida_obligatoria < CURRENT_TIMESTAMP
        FOR UPDATE SKIP LOCKED
    LOOP
        UPDATE public.camas_essi
        SET marcado_para_eliminar = TRUE,
            fecha_marcado_eliminar = CURRENT_TIMESTAMP,
            fecha_modificacion = CURRENT_TIMESTAMP
        WHERE id = v_row.id;

        INSERT INTO public.historial_ocupacion (
            cama_essi_id, codhabcama, codhab, codcama,
            paciente, nrodocidepac, accion, usuario_id, detalle
        ) VALUES (
            v_row.id, v_row."codHabCama", v_row."codHab", v_row."codCama",
            v_row."apeNomPac", v_row."nroDocIdePac",
            'MANUAL_EXPIRADO_MARCADO_ROJO', v_row.usuario_cambio_id,
            'fecha_salida_obligatoria vencida (' || TO_CHAR(v_row.fecha_salida_obligatoria, 'DD/MM/YYYY HH24:MI') || ')'
        );

        v_marcados := v_marcados + 1;
    END LOOP;

    -- 2) Borrar (estado=FALSE) los que llevan en rojo > v_tiempo_rojo_h
    FOR v_row IN
        SELECT id, "codHabCama", "codHab", "codCama", "apeNomPac", "nroDocIdePac",
               usuario_cambio_id, fecha_marcado_eliminar
        FROM public.camas_essi
        WHERE estado = TRUE
          AND marcado_para_eliminar = TRUE
          AND fecha_marcado_eliminar IS NOT NULL
          AND fecha_marcado_eliminar + (v_tiempo_rojo_h || ' hours')::INTERVAL < CURRENT_TIMESTAMP
        FOR UPDATE SKIP LOCKED
    LOOP
        UPDATE public.camas_essi
        SET estado = FALSE,
            fecha_modificacion = CURRENT_TIMESTAMP
        WHERE id = v_row.id;

        INSERT INTO public.historial_ocupacion (
            cama_essi_id, codhabcama, codhab, codcama,
            paciente, nrodocidepac, accion, usuario_id, detalle
        ) VALUES (
            v_row.id, v_row."codHabCama", v_row."codHab", v_row."codCama",
            v_row."apeNomPac", v_row."nroDocIdePac",
            'MANUAL_ELIMINADO_AUTO', v_row.usuario_cambio_id,
            'Eliminado automaticamente tras ' || v_tiempo_rojo_h || ' horas en rojo'
        );

        v_eliminados := v_eliminados + 1;
    END LOOP;

    RETURN jsonb_build_object(
        'estado', 'success', 'codigo', 200,
        'mensaje', jsonb_build_object(
            'marcados_rojo', v_marcados,
            'eliminados', v_eliminados,
            'tiempo_rojo_horas', v_tiempo_rojo_h
        )
    );
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('estado', 'error', 'codigo', 500, 'mensaje', SQLERRM);
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- PASO 4: Verificacion
-- =====================================================

DO $$
BEGIN
    RAISE NOTICE 'Migracion 42 (Fase 2) aplicada. SPs creados:';
    RAISE NOTICE '  - sp_buscar_paciente_por_dni (autocompletar DNI)';
    RAISE NOTICE '  - sp_ingresar_paciente_manual (con DNI obligatorio + fecha salida)';
    RAISE NOTICE '  - sp_procesar_manuales_expirados (cron secundario)';
    RAISE NOTICE 'Recuerda: el cron secundario se ejecuta cada 1 minuto desde el backend.';
END $$;
