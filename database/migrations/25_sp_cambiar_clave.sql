-- =====================================================
-- MIGRACION 25: sp_cambiar_clave
-- =====================================================
-- Recuperada de backend/sql/07_admin_usuarios.sql, que no
-- entro en la consolidacion original de database/migrations/.
-- Sin ella, PUT /api/usuarios/:id/clave falla con
-- "function public.sp_cambiar_clave(...) does not exist".
--
-- El backend la invoca desde src/database/pool.js (cambiarClave).
-- El hash bcrypt lo calcula el backend: aqui solo se persiste.
-- =====================================================

CREATE OR REPLACE FUNCTION public.sp_cambiar_clave(pi_id INT, pi_clave TEXT)
RETURNS JSONB AS $$
DECLARE
    resultado JSONB;
BEGIN
    BEGIN
        UPDATE public.usuarios
           SET clave = pi_clave,
               fecha_modificacion = CURRENT_TIMESTAMP
         WHERE id = pi_id;

        IF FOUND THEN
            resultado := jsonb_build_object('estado', 'success', 'codigo', 200, 'mensaje', 'Clave actualizada correctamente');
        ELSE
            resultado := jsonb_build_object('estado', 'error', 'codigo', 404, 'mensaje', 'Usuario no encontrado');
        END IF;
        RETURN resultado;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN jsonb_build_object('estado', 'error', 'codigo', 500, 'mensaje', SQLERRM);
    END;
END;
$$ LANGUAGE plpgsql;

DO $$
BEGIN
    RAISE NOTICE 'Migracion 25: sp_cambiar_clave creada';
END $$;
