const cron = require('node-cron');
const logger = require('../utils/logger');
const db = require('../database/pool');

// Una sola ejecucion a la vez (para evitar overlap si una corrida tarda mas de 1 minuto)
let enEjecucion = false;
let cronTask = null;

async function ejecutar() {
  if (enEjecucion) {
    logger.debug('Cron manuales-expirados: omitido, hay una ejecucion en curso');
    return;
  }
  enEjecucion = true;
  try {
    const result = await db.procesarManualesExpirados();
    const sp = result[0]?.result;
    if (sp?.estado === 'error') {
      logger.error(`Cron manuales-expirados error: ${sp.mensaje}`);
      return;
    }
    const data = sp?.mensaje || {};
    if ((data.marcados_rojo || 0) > 0 || (data.eliminados || 0) > 0) {
      logger.info(`Cron manuales-expirados: ${data.marcados_rojo} marcados en rojo, ${data.eliminados} eliminados`);
    }
  } catch (err) {
    logger.error(`Cron manuales-expirados excepcion: ${err.message}`);
  } finally {
    enEjecucion = false;
  }
}

function iniciar() {
  // Cada minuto, en el segundo 0
  cronTask = cron.schedule('0 * * * * *', ejecutar);
  logger.info('Cron de manuales expirados iniciado (cada 1 min)');
}

function detener() {
  if (cronTask) {
    cronTask.stop();
    cronTask = null;
  }
}

module.exports = {
  iniciar,
  detener,
  ejecutar,
};
