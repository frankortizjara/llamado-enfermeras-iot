-- Función para actualizar la fecha_modificacion
CREATE OR REPLACE FUNCTION actualizar_fecha_modificacion()
RETURNS TRIGGER AS $$
BEGIN
    NEW.fecha_modificacion = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Modificar la función para actualizar también el campo tiempo_respuesta
CREATE OR REPLACE FUNCTION actualizar_fecha_modificacion()
RETURNS TRIGGER AS $$
BEGIN
    NEW.fecha_modificacion = CURRENT_TIMESTAMP;
    NEW.tiempo_respuesta = NEW.fecha_modificacion - NEW.fecha_registro; -- Calcular la diferencia
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Crear TRIGGER para la tabla usuarios
CREATE TRIGGER actualizar_fecha_modificacion_trigger_usuarios
BEFORE UPDATE ON public.usuarios
FOR EACH ROW
EXECUTE FUNCTION actualizar_fecha_modificacion();

-- Crear TRIGGER para la tabla hospitales
CREATE TRIGGER actualizar_fecha_modificacion_trigger_hospitales
BEFORE UPDATE ON public.hospitales
FOR EACH ROW
EXECUTE FUNCTION actualizar_fecha_modificacion();

-- Crear TRIGGER para la tabla areas
CREATE TRIGGER actualizar_fecha_modificacion_trigger_areas
BEFORE UPDATE ON public.areas
FOR EACH ROW
EXECUTE FUNCTION actualizar_fecha_modificacion();

-- Crear TRIGGER para la tabla habitaciones
CREATE TRIGGER actualizar_fecha_modificacion_trigger_habitaciones
BEFORE UPDATE ON public.habitaciones
FOR EACH ROW
EXECUTE FUNCTION actualizar_fecha_modificacion();

-- Crear TRIGGER para la tabla camas
CREATE TRIGGER actualizar_fecha_modificacion_trigger_camas
BEFORE UPDATE ON public.camas
FOR EACH ROW
EXECUTE FUNCTION actualizar_fecha_modificacion();

-- Crear TRIGGER para la tabla camas essi
CREATE TRIGGER actualizar_fecha_modificacion_trigger_camas
BEFORE UPDATE ON public.camas_essi
FOR EACH ROW
EXECUTE FUNCTION actualizar_fecha_modificacion();

-- Crear TRIGGER para la tabla esp32_dispositivos
--CREATE TRIGGER actualizar_fecha_modificacion_trigger_esp32_dispositivos
--BEFORE UPDATE ON public.esp32_dispositivos
--FOR EACH ROW
--EXECUTE FUNCTION actualizar_fecha_modificacion();

-- Crear TRIGGER para la tabla alertas
CREATE TRIGGER actualizar_fecha_modificacion_trigger_alertas
BEFORE UPDATE ON public.alertas
FOR EACH ROW
EXECUTE FUNCTION actualizar_fecha_modificacion();

-- Crear TRIGGER para la tabla asignaciones_usuarios
CREATE TRIGGER actualizar_fecha_modificacion_trigger_asignaciones_usuarios
BEFORE UPDATE ON public.asignaciones_usuarios
FOR EACH ROW
EXECUTE FUNCTION actualizar_fecha_modificacion();
