-- =====================================================
-- Ampliar campo nota de VARCHAR(8) a VARCHAR(50)
-- =====================================================
-- Permite seleccionar multiples chips (NPO-SOP-TAC)
-- y agregar texto libre junto con los chips.
-- Ejemplo: "NPO-SOP-TAC" o "NPO-TEXTO LIBRE"
-- =====================================================

-- Tabla principal
ALTER TABLE public.camas_essi
ALTER COLUMN nota TYPE VARCHAR(50);

-- Tabla historial (nota_anterior y nota_nueva)
ALTER TABLE public.historial_notas
ALTER COLUMN nota_anterior TYPE VARCHAR(50);

ALTER TABLE public.historial_notas
ALTER COLUMN nota_nueva TYPE VARCHAR(50);
