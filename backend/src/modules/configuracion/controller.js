const db = require('../../database/pool');
const logger = require('../../utils/logger');
const syncJob = require('../../jobs/syncPacientes');

async function listar() {
  logger.debug('Listando configuracion del sistema');
  const result = await db.listarConfiguracionSistema();
  return result[0].result;
}

async function obtener(clave) {
  logger.debug(`Obteniendo configuracion: ${clave}`);
  const result = await db.obtenerConfiguracionSistema(clave);
  return result[0].result;
}

async function actualizar(clave, valor, usuario_id) {
  logger.info(`Actualizando configuracion ${clave} = ${valor} por usuario ${usuario_id}`);
  const result = await db.actualizarConfiguracionSistema(clave, valor, usuario_id);
  const sp = result[0].result;

  // Si el SP exitoso y la clave afecta al cron, reprogramar en caliente
  if (sp.estado === 'success' && clave === 'SYNC_INTERVAL_MINUTES') {
    try {
      await syncJob.reprogramarCron();
      logger.info('Cron de sincronizacion reprogramado tras cambio de SYNC_INTERVAL_MINUTES');
    } catch (err) {
      logger.error(`Error al reprogramar cron: ${err.message}`);
    }
  }

  return sp;
}

module.exports = {
  listar,
  obtener,
  actualizar,
};
