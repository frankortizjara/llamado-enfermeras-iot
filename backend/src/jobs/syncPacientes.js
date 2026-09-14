const axios = require('axios');
const cron = require('node-cron');
const config = require('../config');
const logger = require('../utils/logger');
const db = require('../database/pool');

const AXIOS_TIMEOUT = 30000; // 30 segundos

/**
 * Compara datos actuales con los de la BD y agrega registros faltantes
 */
function compararYAgregarDatos(vDataPacCama, vDatapacCamaOld) {
  const clavesActuales = new Set(
    vDataPacCama.map((item) => `${item.codCama}-${item.codHabCama}`)
  );

  const faltantes = vDatapacCamaOld.filter(
    (item) => !clavesActuales.has(`${item.codCama}-${item.codHabCama}`)
  );

  faltantes.forEach((item) => {
    vDataPacCama.push({
      codCama: item.codCama,
      codHabCama: item.codHabCama,
      desEstCama: item.desEstCama,
      desSerCama: item.desSerCama,
      apeNomPac: '',
      diashospi: '',
      fechaIngreso: '',
      nroDocIdePac: '',
      nroHisCliCas: '',
      tipoDocIdePac: '',
    });
  });

  return vDataPacCama;
}

/**
 * Formatea el nombre del paciente (capitaliza, elimina "Vda De")
 */
function formatearNombrePaciente(nombre) {
  if (!nombre) return '';

  return nombre
    .replace(/vda de/gi, '')
    .toLowerCase()
    .split(' ')
    .map((word) => word.charAt(0).toUpperCase() + word.slice(1))
    .join(' ')
    .trim();
}

/**
 * Parsea el código de cama para extraer habitación y cama
 */
function parsearCodigoCama(codCama) {
  const soloNumeros = /^[0-9]+$/;
  const numerosYLetra = /^[0-9]+[A-Z]{1}$/;

  if (soloNumeros.test(codCama)) {
    return { codHab: codCama, codCama: '' };
  }

  if (numerosYLetra.test(codCama)) {
    return {
      codHab: codCama.slice(0, -1),
      codCama: codCama.slice(-1),
    };
  }

  return null;
}

/**
 * Obtiene todas las configuraciones EsSi únicas de las asignaciones de usuarios
 */
async function obtenerConfigsEsSi() {
  try {
    const result = await db.pool.query(`
      SELECT DISTINCT permisos->'config_essi'->'body' AS essi_body
      FROM public.asignaciones_usuarios
      WHERE permisos->'config_essi'->'body' IS NOT NULL
        AND permisos->'config_essi'->'body'->>'servHosCod' IS NOT NULL
        AND estado = true
    `);

    return result.rows
      .map(r => r.essi_body)
      .filter(b => b && b.servHosCod);
  } catch (err) {
    logger.error(`Error al obtener configs EsSi de asignaciones: ${err.message}`);
    return [];
  }
}

/**
 * Sincroniza pacientes desde la API EsSi para una configuración específica
 */
async function syncPacientesConfig(apiUrl, essiConfig) {
  const configLabel = `servHosCod=${essiConfig.servHosCod}, estEnfCod=${essiConfig.estEnfCod}`;

  try {
    const response = await axios.post(apiUrl, essiConfig, { timeout: AXIOS_TIMEOUT });
    const data = response.data;

    if (data.codExito !== 1) {
      logger.error(`API EsSi respondió con error para ${configLabel}`, { codExito: data.codExito });
      return;
    }

    const vDataItem = data.vDataItem;
    if (!vDataItem || !vDataItem[0] || !vDataItem[0].vDataPacCama) {
      logger.warn(`Respuesta de API EsSi sin datos de pacientes para ${configLabel}`);
      return;
    }

    let vDataPacCama = vDataItem[0].vDataPacCama;
    logger.info(`API EsSi respondió con ${vDataPacCama.length} pacientes para ${configLabel}`);

    // Obtener datos existentes en BD
    const infoResult = await db.consultarInfoHabitaciones();
    const vDatapacCamaOld = infoResult[0]?.result?.mensaje || [];

    // Combinar datos
    vDataPacCama = compararYAgregarDatos(vDataPacCama, vDatapacCamaOld);

    let insertados = 0;
    let actualizados = 0;
    let errores = 0;

    for (const paciente of vDataPacCama) {
      const parsed = parsearCodigoCama(paciente.codCama);

      if (!parsed) {
        logger.warn(`Código de cama no válido: ${paciente.codCama}`);
        errores++;
        continue;
      }

      const dataToInsert = {
        apeNomPac: formatearNombrePaciente(paciente.apeNomPac) || '',
        codHabCama: paciente.codHabCama || '',
        codHab: parsed.codHab || '',
        codCama: parsed.codCama || '',
        desEstCama: paciente.desEstCama || '',
        desSerCama: paciente.desSerCama || '',
        diashospi: paciente.diashospi || '',
        fechaIngreso: paciente.fechaIngreso || '',
        nroDocIdePac: paciente.nroDocIdePac || '',
        nroHisCliCas: paciente.nroHisCliCas || '',
        tipoDocIdePac: paciente.tipoDocIdePac || '',
      };

      try {
        const resultado = await db.cargarDataEsSi(
          dataToInsert.apeNomPac,
          dataToInsert.codHabCama,
          dataToInsert.codHab,
          dataToInsert.codCama,
          dataToInsert.desEstCama,
          dataToInsert.desSerCama,
          dataToInsert.diashospi,
          dataToInsert.fechaIngreso,
          dataToInsert.nroDocIdePac,
          dataToInsert.nroHisCliCas,
          dataToInsert.tipoDocIdePac
        );

        const res = resultado[0]?.result;

        if (res?.estado === 'error') {
          logger.error(`Error al cargar data EsSi - Paciente: ${dataToInsert.apeNomPac}, Hab: ${dataToInsert.codHab}, Cama: ${dataToInsert.codCama} - DB Error: ${res?.mensaje}`);
          errores++;
        } else if (res?.mensaje === 'Registro insertado exitosamente' || res?.mensaje === 'Paciente cambiado en cama') {
          insertados++;
        } else {
          actualizados++;
        }
      } catch (dbError) {
        logger.error(`Error DB al cargar data EsSi - Paciente: ${dataToInsert.apeNomPac}, Hab: ${dataToInsert.codHab}, Cama: ${dataToInsert.codCama} - ${dbError.message}`);
        errores++;
      }
    }

    logger.info(`Sync ${configLabel}: ${vDataPacCama.length} total, ${insertados} insertados, ${actualizados} actualizados, ${errores} errores`);
  } catch (error) {
    if (error.code === 'ECONNABORTED') {
      logger.error(`Timeout al conectar con API EsSi para ${configLabel}`);
    } else if (error.response) {
      logger.error(`Error de respuesta API EsSi para ${configLabel}`, {
        status: error.response.status,
      });
    } else {
      logger.error(`Error en sincronización para ${configLabel}: ${error.message}`);
    }
  }
}

/**
 * Sincroniza pacientes desde la API EsSi para todas las configuraciones asignadas
 */
async function syncPacientes() {
  const apiUrl = config.api.essi;

  if (!apiUrl) {
    logger.error('API_ESSI no está configurada en las variables de entorno. Sincronización cancelada.');
    return;
  }

  logger.info(`Iniciando sincronización de pacientes desde EsSi (${apiUrl})...`);

  // Obtener todas las configuraciones EsSi únicas de las asignaciones de usuarios
  const configs = await obtenerConfigsEsSi();

  if (configs.length === 0) {
    logger.warn('No hay configuraciones EsSi asignadas a usuarios. Sincronización omitida.');
    return;
  }

  logger.info(`Sincronizando ${configs.length} configuracion(es) EsSi`);

  for (const essiConfig of configs) {
    await syncPacientesConfig(apiUrl, essiConfig);
  }

  logger.info('Sincronización de todas las configuraciones completada');
}

// Referencia al cron activo (para reprogramar en caliente)
let cronTask = null;
let cronIntervaloActual = null;

/**
 * Obtiene el intervalo de sincronizacion desde la BD.
 * Cae al valor de .env si la tabla aun no existe (pre-migracion Fase 0).
 */
async function obtenerIntervaloDesdeBD() {
  try {
    const valor = await db.leerValorConfiguracion('SYNC_INTERVAL_MINUTES');
    if (valor === null) {
      return config.api.syncIntervalMinutes;
    }
    const n = parseInt(valor, 10);
    if (!Number.isFinite(n) || n <= 0) {
      logger.warn(`SYNC_INTERVAL_MINUTES en BD invalido (${valor}). Usando fallback ${config.api.syncIntervalMinutes}`);
      return config.api.syncIntervalMinutes;
    }
    return n;
  } catch (err) {
    logger.warn(`No se pudo leer SYNC_INTERVAL_MINUTES desde BD (${err.message}). Usando fallback ${config.api.syncIntervalMinutes}`);
    return config.api.syncIntervalMinutes;
  }
}

/**
 * Inicia el cron job de sincronización
 */
async function iniciarCronSync() {
  if (!config.api.essi) {
    logger.warn('ADVERTENCIA: API_ESSI no está configurada. El cron se iniciará pero la sincronización fallará hasta que se configure.');
  } else {
    logger.info(`API EsSi configurada: ${config.api.essi}`);
  }

  const minutes = await obtenerIntervaloDesdeBD();
  cronTask = cron.schedule(`*/${minutes} * * * *`, syncPacientes);
  cronIntervaloActual = minutes;
  logger.info(`Cron de sincronización de pacientes iniciado (cada ${minutes} minutos)`);
}

/**
 * Reprograma el cron en caliente leyendo el nuevo intervalo desde la BD.
 * Llamado desde el controller de configuracion al cambiar SYNC_INTERVAL_MINUTES.
 */
async function reprogramarCron() {
  const minutes = await obtenerIntervaloDesdeBD();

  if (minutes === cronIntervaloActual) {
    logger.info(`Cron sync: intervalo sin cambios (${minutes} min), no se reprograma`);
    return;
  }

  if (cronTask) {
    cronTask.stop();
    cronTask = null;
  }

  cronTask = cron.schedule(`*/${minutes} * * * *`, syncPacientes);
  cronIntervaloActual = minutes;
  logger.info(`Cron sync reprogramado: ahora cada ${minutes} minutos`);
}

module.exports = {
  syncPacientes,
  iniciarCronSync,
  reprogramarCron,
  obtenerIntervaloDesdeBD,
};
