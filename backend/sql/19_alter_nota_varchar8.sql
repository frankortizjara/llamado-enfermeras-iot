-- =====================================================
-- Ampliar campo nota de VARCHAR(4) a VARCHAR(8)
-- =====================================================
-- Permite notas más largas como "URVI", "NPO-AM", etc.
-- =====================================================

ALTER TABLE public.camas_essi
ALTER COLUMN nota TYPE VARCHAR(8);
