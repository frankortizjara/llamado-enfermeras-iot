-- =============================================================================
-- SEED FINAL: Garantiza que el usuario 'admin' este completo
-- =============================================================================
-- Se ejecuta al final de la inicializacion de PostgreSQL en Docker.
-- Idempotente: se puede ejecutar varias veces sin problema.
--
-- Usuario:    admin
-- Contrasena: CAMBIA_ESTA_PASSWORD   (hash bcrypt precalculado)
-- Rol:        admin (acceso total)
-- Permisos:   todos en true
-- =============================================================================

DO $$
DECLARE
    v_usuario_id INT;
    v_area_id    INT;
    v_permisos_full JSONB := '{
        "dispositivos": true,
        "analytics": true,
        "contenido_tv": true,
        "contenido_tv_efemerides": true,
        "contenido_tv_cumpleanos": true,
        "contenido_tv_avisos": true,
        "contenido_tv_audio": true,
        "contenido_tv_config": true,
        "usuarios": true
    }'::jsonb;
BEGIN
    -- 1) Asegurar que existe el usuario admin
    INSERT INTO public.usuarios (nombre, usuario, clave, estado, fecha_registro, fecha_modificacion)
    VALUES (
        'Admin Sistema',
        'admin',
        '$2b$10$TePIMUiEOu5BbymhTeFgHOMMIJWBZ3TAxm4F0Twy7pkFfOnb9KlLW', -- CAMBIA_ESTA_PASSWORD
        true,
        NOW(),
        NOW()
    )
    ON CONFLICT (usuario) DO UPDATE
        SET estado = true,
            fecha_modificacion = NOW();

    SELECT id INTO v_usuario_id FROM public.usuarios WHERE usuario = 'admin';

    -- 2) Asegurar que existe un area (UCI) donde asignarlo
    SELECT id INTO v_area_id FROM public.areas ORDER BY id LIMIT 1;
    IF v_area_id IS NULL THEN
        INSERT INTO public.areas (nombre, estado, fecha_registro, fecha_modificacion)
        VALUES ('UCI', true, NOW(), NOW())
        RETURNING id INTO v_area_id;
    END IF;

    -- 3) Asegurar columna permisos (por si algun SP vino antes de la migracion 08)
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name   = 'asignaciones_usuarios'
          AND column_name  = 'permisos'
    ) THEN
        ALTER TABLE public.asignaciones_usuarios
            ADD COLUMN permisos JSONB DEFAULT '{}'::jsonb;
    END IF;

    -- 4) Asignar admin con rol=admin y permisos completos
    IF EXISTS (
        SELECT 1 FROM public.asignaciones_usuarios WHERE usuario_id = v_usuario_id
    ) THEN
        UPDATE public.asignaciones_usuarios
           SET rol      = 'admin',
               area_id  = v_area_id,
               estado   = true,
               permisos = v_permisos_full,
               fecha_modificacion = NOW()
         WHERE usuario_id = v_usuario_id;
    ELSE
        INSERT INTO public.asignaciones_usuarios
            (usuario_id, area_id, rol, estado, permisos, fecha_registro, fecha_modificacion)
        VALUES
            (v_usuario_id, v_area_id, 'admin', true, v_permisos_full, NOW(), NOW());
    END IF;

    RAISE NOTICE 'Usuario admin listo: id=%, area_id=%, rol=admin, permisos=completos', v_usuario_id, v_area_id;
END $$;

-- Verificacion final (visible en los logs de docker compose logs postgres)
DO $$
DECLARE
    v_info RECORD;
BEGIN
    SELECT u.usuario, u.nombre, au.rol, au.permisos
      INTO v_info
      FROM public.usuarios u
      JOIN public.asignaciones_usuarios au ON au.usuario_id = u.id
     WHERE u.usuario = 'admin';

    RAISE NOTICE '==============================================';
    RAISE NOTICE 'ADMIN CREADO CORRECTAMENTE';
    RAISE NOTICE '  usuario:  %', v_info.usuario;
    RAISE NOTICE '  nombre:   %', v_info.nombre;
    RAISE NOTICE '  rol:      %', v_info.rol;
    RAISE NOTICE '  permisos: %', v_info.permisos;
    RAISE NOTICE '  clave:    CAMBIA_ESTA_PASSWORD  (CAMBIAR EN PRODUCCION)';
    RAISE NOTICE '==============================================';
END $$;
