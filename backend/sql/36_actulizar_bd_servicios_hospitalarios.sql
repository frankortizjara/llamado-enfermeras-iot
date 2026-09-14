-- =====================================================
-- MIGRACIÓN 36 - PASO 2: UPSERT servicios_hospitalarios
-- Actualiza serv_hos_cod si ya existe, inserta si no existe
-- =====================================================

INSERT INTO public.servicios_hospitalarios (servicio, serv_hos_cod, estacion, est_enf_cod)
VALUES
    -- HOSPITALIZACIÓN
    ('CIRUGIA GENERAL 1',            'B42',  'HOSP. CIRUGIA 1',        '19'),
    ('CIRUGIA GENERAL 1',            'B42',  'ANEXO ESPEC. QUIRURG',   '22'),
    ('CIRUGIA ONCOLOGICA',           'B39',  'CIR.ONCOLO.CONTING',     'QO'),
    ('CIRUGIA PEDIATRICA',           'D13',  'CIRUG_PEDIATRICA',       '38'),
    ('CIRUGIA PLASTICA',             'B51',  'CIRUGIA PLASTICA',       '23'),
    ('CIR. CABEZA Y CUELLO',         'B11',  'CIR_CABEZA Y CUE',       '17'),
    ('CIR. TORAX Y CARDIOVASCULAR',  'B31',  'CIR_CARDIOVASCU',        '18'),
    ('CARDIOLOGIA',                  'A21',  'CARDIOLOGIA CONTING',    'C'),
    ('DERMATOLOGIA',                 'A31',  'DERMATOLOGIA CONTING',   'DE'),
    ('ENDOCRINOLOGIA',               'A41',  'ENDOCRINOLOGIA',         '3'),
    ('GASTROENTEROLOGIA',            'A51',  'DEP ESPECIAL.MED III',   'GE'),
    ('GERIATRIA',                    'A71',  'DPTO.ESPEC.MEDIC I',     'GM'),
    ('GERIATRIA',                    'A71',  'GERIATRIA',              '6'),
    ('GINECOLOGIA',                  'C12',  'GINECOLOGIA',            '28'),
    ('GINECOLOGIA ONCOLOGICA',       'AG2',  'GINECO ONCO',            '42'),
    ('HEMATOLOGIA CLINICA',          'A81',  'HEMAT PEDIATR CONTING',  'HC'),
    ('INFECTOLOGIA',                 'AJ1',  'INFECTOLOGIA CONTING',   '16'),
    ('MEDICINA INTENSIVA (UCI)',      'AK1',  'CUID INTENSIVOS ADUL',   '28'),
    ('MEDICINA INTENSIVA (UCIN)',     'AK1',  'CUID INTERMEDIOS',       '29'),
    ('MEDICINA INTENSIVA (RESP.)',    'AK1',  'TERAPIA RESPIRATORIA',   'TR'),
    ('MEDICINA INTERNA',             'AC1',  'VARONES IV',             'I'),
    ('MEDICINA INTERNA',             'AC1',  'VARONES II',             'V2'),
    ('MEDICINA INTERNA',             'AC1',  'DAMAS I',                'MI'),
    ('MEDICINA INTERNA',             'AC1',  'UCEMI 1',                'NU'),
    ('MEDICINA INTERNA',             'AC1',  'UCEMI 2',                'N2'),
    ('MEDICINA INTERNA',             'AC1',  'UCEMI 3',                'N3'),
    ('MEDICINA INTERNA',             'AC1',  'ANEXO ESPEC. MEDICAS',   '26'),
    ('NEFROLOGIA',                   'AD1',  'NEFROLOGIA CONTING',     'EN'),
    ('NEONATOLOGIA',                 'D14',  'UCI NEONATALES',         'UN'),
    ('NEONATOLOGIA',                 'D14',  'UCIN NEONATOLOGIA A',    'UA'),
    ('NEONATOLOGIA',                 'D14',  'UCIN NEONATOLOGIA B',    'UB'),
    ('NEUMOLOGIA',                   'AE1',  'NEUMOLOGIA CONTING',     'EN'),
    ('NEUROCIRUGIA',                 'B61',  'NEUROCIRUGIA',           '24'),
    ('NEUROLOGIA',                   'AF1',  'DPTO. ESPEC.MEDIC I',    'NM'),
    ('NEUROLOGIA',                   'AF1',  'NEUROLOGIA CONTING',     'EN'),
    ('OBSTETRICIA',                  'C13',  'ARO',                    'AR'),
    ('OBSTETRICIA',                  'C13',  'PATOLOGIA I CONTING',    'P1'),
    ('OBSTETRICIA',                  'C13',  'PATOLOGIA II CONTING',   'P2'),
    ('ONCOLOGIA MEDICA',             'AG3',  'ONCOLOGIA CONTING',      'EN'),
    ('ORTOPEDIA Y TRAUMATOLOGIA',    'B81',  'TRAUMATOLOGIA CONTING',  'OT'),
    ('OTORRINOLARINGOLOGIA',         'B91',  'OTORRINO',               '26'),
    ('PEDIATRIA',                    'D11',  'PEDIATRIA CONTING',      '30'),
    ('PEDIATRIA (UCI)',               'D11',  'UCI PEDIATRIA',          '34'),
    ('PSIQUIATRIA',                  'AH1',  'DPTO.ESPEC.MEDIC I',     'EM'),
    ('REUMATOLOGIA',                 'AI1',  'SERV_CUIDADO',           '15'),
    ('UROLOGIA',                     'BA1',  'UROLOGIA ESPECIALIDA',   '27'),
    -- URGENCIAS/EMERGENCIA
    ('EMERGENCIA (Obs A)',            'AB1',  'OBSERVACION A',          'OA'),
    ('EMERGENCIA (Obs B)',            'AB1',  'OBSERVACION B',          'OB'),
    ('EMERGENCIA (Obs C-L)',          'AB1',  'OBSERVACION C..L',       'OC..OL'),
    -- CENTRO OBSTETRICO / QUIRURGICO
    ('OBSTETRICIA (Puerperio)',       'C13',  'PUERPERIO INMEDIATO',    'PI'),
    ('OBSTETRICIA (Sala Partos)',     'C13',  'SALA PARTOS',            'SP'),
    ('ANESTESIA/REANIMACION',        'BB1',  'CANTA CALLAO',           'CC'),
    ('ANESTESIA/REANIMACION',        'BB1',  'CENTRO QX (Recuper.)',   'CQ')
ON CONFLICT (servicio, est_enf_cod)
DO UPDATE SET
    serv_hos_cod = EXCLUDED.serv_hos_cod,
    estacion     = EXCLUDED.estacion;