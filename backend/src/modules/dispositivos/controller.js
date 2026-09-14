const db = require('../../database/pool');
const logger = require('../../utils/logger');
const mqttService = require('../../services/mqtt.service');

async function agregarESP32(data) {
  const { numero_serial, direccion_mac, ip, estado = true } = data;

  logger.debug(`Agregando dispositivo ESP32: ${numero_serial}`);

  const result = await db.agregarESP32(numero_serial, direccion_mac, ip, estado);
  return result[0].result;
}

async function agregarRegistro(data) {
  const { numero_serial, area_id, habitacion_id, codigo_cama, tipo_alerta } = data;

  logger.debug(`Agregando registro de alerta - Serial: ${numero_serial}, Tipo: ${tipo_alerta}`);

  const result = await db.agregarRegistro(numero_serial, area_id, habitacion_id, codigo_cama, tipo_alerta);
  const dbResult = result[0].result;

  // Publicar via MQTT para ESP32 luces
  if (dbResult.codigo === 201 && (tipo_alerta === 1 || tipo_alerta === 2)) {
    // Alerta creada: encender luz
    mqttService.publishAlerta(habitacion_id, 'ON', tipo_alerta, codigo_cama);
  } else if (tipo_alerta === 3 && (dbResult.codigo === 200 || dbResult.codigo === 201)) {
    // Alerta cancelada: verificar si quedan alertas activas
    const alertasActivas = await db.contarAlertasActivas(habitacion_id);
    if (alertasActivas === 0) {
      mqttService.publishAlerta(habitacion_id, 'OFF');
    }
  }

  return dbResult;
}

async function heartbeat(data) {
  const { numero_serial, direccion_mac, ip, tipo_dispositivo, habitacion_id, relay_estado, uptime, rssi } = data;

  logger.debug(`Heartbeat - Serial: ${numero_serial}, Tipo: ${tipo_dispositivo}, Hab: ${habitacion_id}`);

  const result = await db.heartbeatDispositivo(numero_serial, direccion_mac, ip, tipo_dispositivo, habitacion_id, relay_estado, uptime, rssi);
  return result[0].result;
}

async function listarDispositivos() {
  logger.debug('Listando dispositivos ESP32');

  const result = await db.listarDispositivos();
  return result[0].result;
}

async function estadisticasDispositivos(data) {
  const { fecha_inicio, fecha_fin } = data;

  logger.debug(`Estadisticas dispositivos: ${fecha_inicio} - ${fecha_fin}`);

  const result = await db.estadisticasDispositivos(fecha_inicio, fecha_fin);
  return result[0].result;
}

async function eventosDispositivo(data) {
  const { numero_serial, fecha_inicio, fecha_fin } = data;

  logger.debug(`Eventos dispositivo: ${numero_serial} (${fecha_inicio} - ${fecha_fin})`);

  const result = await db.eventosDispositivo(numero_serial, fecha_inicio, fecha_fin);
  return result[0].result;
}

async function listarControlesRf() {
  logger.debug('Listando controles RF');
  const result = await db.listarControlesRf();
  return result[0].result;
}

async function agregarControlRf(data) {
  const { id = 0, habitacion_id, cama, dip_config, descripcion = '', estado = true } = data;
  logger.debug(`Agregando/editando control RF - Hab: ${habitacion_id}, Cama: ${cama}`);
  const result = await db.agregarControlRf(id, habitacion_id, cama, dip_config, descripcion, estado);
  return result[0].result;
}

async function eliminarControlRf(id) {
  logger.debug(`Eliminando control RF: ${id}`);
  const result = await db.eliminarControlRf(id);
  return result[0].result;
}

async function purgarEventosDispositivos() {
  logger.debug('Purgando eventos de dispositivos');
  const result = await db.purgarEventosDispositivos();
  return result[0].result;
}

async function purgarDispositivosEsp32() {
  logger.debug('Purgando dispositivos ESP32');
  const result = await db.purgarDispositivosEsp32();
  return result[0].result;
}

async function eliminarDispositivo(id) {
  logger.debug(`Eliminando dispositivo ESP32 id: ${id}`);
  const result = await db.eliminarDispositivoPorId(id);
  return result[0].result;
}

module.exports = {
  agregarESP32,
  agregarRegistro,
  heartbeat,
  listarDispositivos,
  estadisticasDispositivos,
  eventosDispositivo,
  listarControlesRf,
  agregarControlRf,
  eliminarControlRf,
  purgarEventosDispositivos,
  purgarDispositivosEsp32,
  eliminarDispositivo,
};