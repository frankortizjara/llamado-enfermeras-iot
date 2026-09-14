const db = require('../../database/pool');
const logger = require('../../utils/logger');

async function tiemposRespuesta(data) {
  const { area_id, fecha_inicio, fecha_fin } = data;
  logger.debug(`Analytics: tiempos respuesta area ${area_id}`);
  const result = await db.analyticsTiemposRespuesta(area_id, fecha_inicio, fecha_fin);
  return result[0].result;
}

async function historialNotas(data) {
  const { area_id, fecha_inicio, fecha_fin } = data;
  logger.debug(`Analytics: historial notas area ${area_id}`);
  const result = await db.analyticsHistorialNotas(area_id, fecha_inicio, fecha_fin);
  return result[0].result;
}

async function ocupacion(data) {
  const { area_id, fecha_inicio, fecha_fin } = data;
  logger.debug(`Analytics: ocupacion area ${area_id}`);
  try {
    const result = await db.analyticsOcupacion(area_id, fecha_inicio, fecha_fin);
    return result[0].result;
  } catch (error) {
    logger.error(`Error en analytics ocupacion: ${error.message}`);
    throw error;
  }
}

async function frecuenciaAlertas(data) {
  const { area_id, fecha_inicio, fecha_fin } = data;
  logger.debug(`Analytics: frecuencia alertas area ${area_id}`);
  const result = await db.analyticsFrecuenciaAlertas(area_id, fecha_inicio, fecha_fin);
  return result[0].result;
}

async function purgarAnalytics(data) {
  const { area_id } = data;
  logger.debug(`Purgando analytics area ${area_id}`);
  const result = await db.purgarAnalytics(area_id);
  return result[0].result;
}

module.exports = {
  tiemposRespuesta,
  historialNotas,
  ocupacion,
  frecuenciaAlertas,
  purgarAnalytics,
};
