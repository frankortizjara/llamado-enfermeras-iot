const mqtt = require('mqtt');
const logger = require('../utils/logger');
const config = require('../config');

let client = null;
let db = null; // Se inicializa lazy para evitar dependencia circular

function getDb() {
  if (!db) db = require('../database/pool');
  return db;
}

/**
 * Conectar al broker MQTT
 */
function connect() {
  const { host, port, user, password } = config.mqtt;
  const url = `mqtt://${host}:${port}`;

  logger.info(`MQTT: Conectando a ${url}...`);

  client = mqtt.connect(url, {
    username: user,
    password: password,
    clientId: `enfermeras-backend-${Date.now()}`,
    reconnectPeriod: 5000,
    connectTimeout: 10000,
    clean: true,
  });

  client.on('connect', () => {
    logger.info('MQTT: Conectado al broker');

    // Suscribirse a LWT de todos los dispositivos
    client.subscribe('enfermeras/lwt/#', { qos: 1 }, (err) => {
      if (err) {
        logger.error('MQTT: Error suscribiendo a LWT', { error: err.message });
      } else {
        logger.info('MQTT: Suscrito a enfermeras/lwt/#');
      }
    });
  });

  client.on('message', (topic, message) => {
    handleMessage(topic, message.toString());
  });

  client.on('reconnect', () => {
    logger.warn('MQTT: Reconectando...');
  });

  client.on('error', (err) => {
    logger.error('MQTT: Error de conexion', { error: err.message });
  });

  client.on('offline', () => {
    logger.warn('MQTT: Desconectado del broker');
  });

  return client;
}

/**
 * Procesar mensajes MQTT entrantes
 */
function handleMessage(topic, payload) {
  // LWT: enfermeras/lwt/{numero_serial}
  if (topic.startsWith('enfermeras/lwt/')) {
    const numeroSerial = topic.split('/')[2];
    const estado = payload.trim(); // "ONLINE" o "OFFLINE"

    if (estado === 'ONLINE' || estado === 'OFFLINE') {
      logger.info(`MQTT LWT: ${numeroSerial} -> ${estado}`);
      registrarEstadoDispositivo(numeroSerial, estado === 'ONLINE');
    }
  }
}

/**
 * Registrar cambio de estado online/offline en la base de datos
 */
async function registrarEstadoDispositivo(numeroSerial, online) {
  try {
    const pool = getDb().pool;
    // Actualizar estado del dispositivo
    await pool.query(
      `UPDATE esp32_dispositivos
       SET estado = $1, ultima_conexion = NOW()
       WHERE numero_serial = $2`,
      [online, numeroSerial]
    );

    // Registrar evento
    await pool.query(
      `INSERT INTO dispositivo_eventos (dispositivo_id, tipo_evento, descripcion)
       SELECT id, $1, $2
       FROM esp32_dispositivos WHERE numero_serial = $3`,
      [
        online ? 'ONLINE' : 'OFFLINE',
        online ? 'Dispositivo conectado (MQTT LWT)' : 'Dispositivo desconectado (MQTT LWT)',
        numeroSerial
      ]
    );
  } catch (err) {
    logger.error(`MQTT LWT: Error registrando estado de ${numeroSerial}`, { error: err.message });
  }
}

/**
 * Publicar alerta para una habitacion
 * @param {number} habitacionId - ID de la habitacion
 * @param {string} action - "ON" o "OFF"
 * @param {number} tipoAlerta - 1=urgente, 2=emergencia (solo para ON)
 * @param {string} cama - codigo de cama (opcional)
 */
function publishAlerta(habitacionId, action, tipoAlerta = 0, cama = '') {
  if (!client || !client.connected) {
    logger.warn('MQTT: No conectado, no se puede publicar alerta');
    return;
  }

  const topic = `enfermeras/alertas/${habitacionId}`;
  const payload = JSON.stringify({
    action,
    tipo: tipoAlerta,
    cama,
    ts: Date.now(),
  });

  // retain=true para que un ESP32 que reconecte reciba el ultimo estado
  client.publish(topic, payload, { qos: 1, retain: true }, (err) => {
    if (err) {
      logger.error(`MQTT: Error publicando en ${topic}`, { error: err.message });
    } else {
      logger.debug(`MQTT: Publicado ${topic} -> ${payload}`);
    }
  });
}

/**
 * Desconectar del broker
 */
function disconnect() {
  if (client) {
    client.end(true);
    logger.info('MQTT: Desconectado');
  }
}

/**
 * Verificar si esta conectado
 */
function isConnected() {
  return client && client.connected;
}

module.exports = {
  connect,
  publishAlerta,
  disconnect,
  isConnected,
};
