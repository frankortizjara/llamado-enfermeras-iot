-- Crear la tabla usuarios
CREATE TABLE usuarios (
  id SERIAL PRIMARY KEY,
  nombre VARCHAR(255) NOT NULL,
  usuario VARCHAR(255) UNIQUE NOT NULL,
  clave VARCHAR(255) NOT NULL, -- Recuerda almacenar cifrada
  estado BOOLEAN NOT NULL,
  fecha_registro TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  fecha_modificacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE hospitales (
    hospital_id SERIAL PRIMARY KEY,
    cod_renaes INTEGER UNIQUE,
    cod_ses INTEGER UNIQUE,
    cod_eess INTEGER UNIQUE,
    tipo_ra1 VARCHAR(10), -- Ajustado a VARCHAR ya que 'C' parece ser texto
    tipo VARCHAR(50),
    nombre VARCHAR(100),
    departamento VARCHAR(50),
    provincia VARCHAR(50),
    distrito VARCHAR(50),
    categoria VARCHAR(50),
    latitud DECIMAL(15, 12), -- Para mayor precisión en coordenadas
    longitud DECIMAL(15, 12), -- Igual que la latitud
    estado VARCHAR(50), -- Nueva columna para almacenar el estado (por ejemplo: "FUNCIONA")
    enlace TEXT, -- Para almacenar los enlaces largos de Google Maps
    fecha_registro TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    fecha_modificacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Crear la tabla áreas
CREATE TABLE areas (
  id SERIAL PRIMARY KEY,
  cod_ses INTEGER NOT NULL, -- Relacionado con hospitales.cod_ses
  nombre VARCHAR(255) NOT NULL,
  estado BOOLEAN NOT NULL,
  fecha_registro TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  fecha_modificacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_hospitales_cod_ses FOREIGN KEY (cod_ses) REFERENCES hospitales (cod_ses)
);

-- Crear la tabla habitaciones
CREATE TABLE habitaciones (
  id SERIAL PRIMARY KEY,
  area_id INTEGER NOT NULL,
  nombre INTEGER NOT NULL,
  estado BOOLEAN NOT NULL,
  fecha_registro TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  fecha_modificacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_areas FOREIGN KEY (area_id) REFERENCES areas (id)
);

-- Crear la tabla camas
CREATE TABLE camas (
  id SERIAL PRIMARY KEY,
  habitacion_id INTEGER NOT NULL,
  nombre VARCHAR(255) NOT NULL,
  paciente VARCHAR(255),
  estado BOOLEAN NOT NULL,
  fecha_registro TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  fecha_modificacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_habitaciones FOREIGN KEY (habitacion_id) REFERENCES habitaciones (id)
);

-- Crear la tabla camas essi

-- Crear la tabla camas EsSi
CREATE TABLE camas_essi (
  id SERIAL PRIMARY KEY,
  "codHabCama" VARCHAR(255) NOT NULL,
  "codHab" VARCHAR(255) NOT NULL,
  "codCama" VARCHAR(255) NOT NULL,
  "apeNomPac" VARCHAR(255) NOT NULL,
  "desEstCama" VARCHAR(255) NOT NULL,
  "desSerCama" VARCHAR(255) NOT NULL,
  "diashospi" VARCHAR(255) NOT NULL,
  "fechaIngreso" VARCHAR(255) NOT NULL,
  "nroDocIdePac" VARCHAR(255) NOT NULL,
  "nroHisCliCas" VARCHAR(255) NOT NULL,
  "tipoDocIdePac" VARCHAR(255) NOT NULL,
  estado BOOLEAN NOT NULL DEFAULT TRUE, 
  fecha_registro TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  fecha_modificacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

ALTER TABLE public.camas_essi 
ADD nota VARCHAR(4) default '';

ALTER TABLE public.camas_essi 
ADD fecha_nota VARCHAR(255) default '';

-- Crear la tabla esp32_dispositivos
CREATE TABLE esp32_dispositivos (
  id SERIAL PRIMARY KEY,
  numero_serial VARCHAR(12) UNIQUE NOT NULL,
  direccion_mac VARCHAR(17) UNIQUE NOT NULL,
  ip VARCHAR(45),
  estado BOOLEAN NOT NULL,
  fecha_registro TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  fecha_modificacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Crear la tabla alertas
CREATE TABLE alertas (
  id SERIAL PRIMARY KEY,
  dispositivo_id INTEGER NOT NULL,
  area_id INTEGER NOT NULL,
  habitacion_id INTEGER NOT NULL,
  codigo_cama VARCHAR(50) NOT NULL,
  tipo_alerta INTEGER NOT NULL,
  estado_alerta BOOLEAN NOT NULL DEFAULT TRUE,
  fecha_registro TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  fecha_modificacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  tiempo_respuesta INTERVAL,
  CONSTRAINT fk_esp32_dispositivos FOREIGN KEY (dispositivo_id) REFERENCES esp32_dispositivos (id),
  CONSTRAINT fk_areas_alertas FOREIGN KEY (area_id) REFERENCES areas (id),
  --CONSTRAINT fk_habitaciones_alertas FOREIGN KEY (habitacion_id) REFERENCES habitaciones (id)
);

-- Crear la tabla asignaciones_usuarios
CREATE TABLE asignaciones_usuarios (
  id SERIAL PRIMARY KEY,
  usuario_id INTEGER NOT NULL,
  area_id INTEGER NOT NULL,
  rol VARCHAR(50) NOT NULL,
  estado BOOLEAN NOT NULL,
  fecha_asignacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  fecha_registro TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  fecha_modificacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_usuarios FOREIGN KEY (usuario_id) REFERENCES usuarios (id),
  CONSTRAINT fk_areas_asignaciones FOREIGN KEY (area_id) REFERENCES areas (id)
);

-- Crear la tabla variables
CREATE TABLE variables (
  id SERIAL PRIMARY KEY,
  nombre_variable VARCHAR(50) NOT NULL
);