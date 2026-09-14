-- ============================================
-- TABLA: pantallas_tv
-- Pantallas TV públicas configurables por admin
-- ============================================

CREATE TABLE IF NOT EXISTS pantallas_tv (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    token VARCHAR(64) NOT NULL UNIQUE,
    area_id INTEGER REFERENCES areas(id) ON DELETE SET NULL,
    area_nombre VARCHAR(255),
    cod_hab_cama VARCHAR(255),
    estado BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_pantallas_tv_token ON pantallas_tv(token);
CREATE INDEX IF NOT EXISTS idx_pantallas_tv_estado ON pantallas_tv(estado);

-- ============================================
-- SP: Listar pantallas TV
-- ============================================
CREATE OR REPLACE FUNCTION sp_listar_pantallas_tv()
RETURNS JSONB AS $$
DECLARE
    v_result JSONB;
BEGIN
    SELECT jsonb_build_object(
        'estado', 'success',
        'codigo', 200,
        'mensaje', COALESCE(
            (SELECT jsonb_agg(row_data)
            FROM (
                SELECT jsonb_build_object(
                    'id', p.id,
                    'nombre', p.nombre,
                    'token', p.token,
                    'area_id', p.area_id,
                    'area_nombre', COALESCE(p.area_nombre, a.nombre),
                    'cod_hab_cama', p.cod_hab_cama,
                    'estado', p.estado,
                    'created_at', p.created_at
                ) AS row_data
                FROM pantallas_tv p
                LEFT JOIN areas a ON a.id = p.area_id
                ORDER BY p.id
            ) t
            ), '[]'::jsonb
        )
    ) INTO v_result;

    RETURN v_result;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- SP: Agregar/editar pantalla TV
-- ============================================
CREATE OR REPLACE FUNCTION sp_agregar_pantalla_tv(
    p_id INTEGER,
    p_nombre VARCHAR,
    p_token VARCHAR,
    p_area_id INTEGER,
    p_area_nombre VARCHAR,
    p_cod_hab_cama VARCHAR,
    p_estado BOOLEAN
)
RETURNS JSONB AS $$
DECLARE
    v_result JSONB;
    v_id INTEGER;
BEGIN
    IF p_id IS NOT NULL AND p_id > 0 THEN
        -- Editar
        UPDATE pantallas_tv
        SET nombre = p_nombre,
            area_id = p_area_id,
            area_nombre = p_area_nombre,
            cod_hab_cama = p_cod_hab_cama,
            estado = p_estado,
            updated_at = NOW()
        WHERE id = p_id
        RETURNING id INTO v_id;

        IF v_id IS NULL THEN
            RETURN jsonb_build_object('estado', 'error', 'codigo', 404, 'mensaje', 'Pantalla no encontrada');
        END IF;
    ELSE
        -- Crear
        INSERT INTO pantallas_tv (nombre, token, area_id, area_nombre, cod_hab_cama, estado)
        VALUES (p_nombre, p_token, p_area_id, p_area_nombre, p_cod_hab_cama, p_estado)
        RETURNING id INTO v_id;
    END IF;

    RETURN jsonb_build_object('estado', 'success', 'codigo', 200, 'mensaje', v_id);
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- SP: Eliminar pantalla TV
-- ============================================
CREATE OR REPLACE FUNCTION sp_eliminar_pantalla_tv(p_id INTEGER)
RETURNS JSONB AS $$
BEGIN
    DELETE FROM pantallas_tv WHERE id = p_id;
    RETURN jsonb_build_object('estado', 'success', 'codigo', 200, 'mensaje', 'Pantalla eliminada');
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- SP: Obtener pantalla TV por token (público)
-- ============================================
CREATE OR REPLACE FUNCTION sp_obtener_pantalla_tv_por_token(p_token VARCHAR)
RETURNS JSONB AS $$
DECLARE
    v_result JSONB;
BEGIN
    SELECT jsonb_build_object(
        'estado', 'success',
        'codigo', 200,
        'mensaje', jsonb_build_object(
            'id', p.id,
            'nombre', p.nombre,
            'token', p.token,
            'area_id', p.area_id,
            'area_nombre', COALESCE(p.area_nombre, a.nombre),
            'cod_hab_cama', p.cod_hab_cama
        )
    )
    INTO v_result
    FROM pantallas_tv p
    LEFT JOIN areas a ON a.id = p.area_id
    WHERE p.token = p_token AND p.estado = TRUE;

    IF v_result IS NULL THEN
        RETURN jsonb_build_object('estado', 'error', 'codigo', 404, 'mensaje', 'Pantalla no encontrada o desactivada');
    END IF;

    RETURN v_result;
END;
$$ LANGUAGE plpgsql;
