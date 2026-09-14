const db = require('../../database/pool');
const logger = require('../../utils/logger');

async function agregarArea(data) {
  const { id = 0, cod_ses, nombre, estado } = data;
  logger.debug(`Agregando/actualizando área: ${nombre}`);
  const result = await db.agregarArea(id, cod_ses, nombre, estado);
  return result[0].result;
}

async function agregarHabitacion(data) {
  const { id = 0, area_id, nombre, estado } = data;
  logger.debug(`Agregando/actualizando habitación: ${nombre} en área ${area_id}`);
  const result = await db.agregarHabitacion(id, area_id, nombre, estado);
  return result[0].result;
}

async function agregarCama(data) {
  const { id = 0, habitacion_id, nombre, paciente, estado } = data;
  logger.debug(`Agregando/actualizando cama: ${nombre} en habitación ${habitacion_id}`);
  const result = await db.agregarCama(id, habitacion_id, nombre, paciente, estado);
  return result[0].result;
}

module.exports = {
  agregarArea,
  agregarHabitacion,
  agregarCama,
};
