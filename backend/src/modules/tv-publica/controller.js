const db = require('../../database/pool');
const logger = require('../../utils/logger');

async function obtenerPantallaPorToken(token) {
  logger.debug(`Obteniendo pantalla TV por token: ${token}`);
  const result = await db.obtenerPantallaTvPorToken(token);
  return result[0].result;
}

async function consultarHabitacionesPorToken(token) {
  const pantalla = await obtenerPantallaPorToken(token);
  if (pantalla.estado === 'error') return pantalla;

  const config = pantalla.mensaje;
  const codHabCama = config.cod_hab_cama || config.area_nombre || '';
  logger.debug(`TV pública [${config.nombre}] consultando habitaciones: ${codHabCama}`);

  const result = await db.consultarHabitacionesEsSi(codHabCama);
  return result[0].result;
}

async function consultarAlertasPorToken(token) {
  const pantalla = await obtenerPantallaPorToken(token);
  if (pantalla.estado === 'error') return pantalla;

  const config = pantalla.mensaje;
  if (!config.area_id) {
    return { estado: 'error', codigo: 400, mensaje: 'Pantalla sin área configurada' };
  }

  logger.debug(`TV pública [${config.nombre}] consultando alertas: área ${config.area_id}`);
  const result = await db.consultarAlertas(config.area_id);
  return result[0].result;
}

async function obtenerContenidoPorToken(token) {
  const pantalla = await obtenerPantallaPorToken(token);
  if (pantalla.estado === 'error') return pantalla;

  const config = pantalla.mensaje;
  const now = new Date();
  const dia = now.getDate();
  const mes = now.getMonth() + 1;

  logger.debug(`TV pública [${config.nombre}] contenido del día (${dia}/${mes}) área: ${config.area_id}`);
  const result = await db.obtenerContenidoTv(dia, mes, config.area_id || null);
  return result[0].result;
}

async function obtenerConfigPorToken(token) {
  const pantalla = await obtenerPantallaPorToken(token);
  if (pantalla.estado === 'error') return pantalla;

  logger.debug(`TV pública [${pantalla.mensaje.nombre}] obteniendo config`);
  const result = await db.obtenerConfigTv();
  return result[0].result;
}

module.exports = {
  obtenerPantallaPorToken,
  consultarHabitacionesPorToken,
  consultarAlertasPorToken,
  obtenerContenidoPorToken,
  obtenerConfigPorToken,
};
