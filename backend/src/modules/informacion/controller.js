const db = require('../../database/pool');
const logger = require('../../utils/logger');
const mqttService = require('../../services/mqtt.service');

async function consultarHabitaciones(data) {
  const { id } = data;
  logger.debug(`Consultando habitaciones para usuario: ${id}`);
  const result = await db.consultarHabitaciones(id);
  return result[0].result;
}

async function consultarHabitacionesEsSi(data) {
  const { codHabCama } = data;
  logger.debug(`Consultando habitaciones EsSi: ${codHabCama}`);
  const result = await db.consultarHabitacionesEsSi(codHabCama);
  return result[0].result;
}

async function consultarAlertas(data) {
  const { area_id } = data;
  logger.debug(`Consultando alertas para area: ${area_id}`);
  const result = await db.consultarAlertas(area_id);
  return result[0].result;
}

async function consultarInfoHabitaciones() {
  logger.debug('Consultando info de habitaciones');
  const result = await db.consultarInfoHabitaciones();
  return result[0].result;
}

async function cargarDataEsSi(data) {
  const {
    apeNomPac, codHabCama, codHab, codCama, desEstCama,
    desSerCama, diashospi, fechaIngreso, nroDocIdePac,
    nroHisCliCas, tipoDocIdePac
  } = data;

  logger.debug(`Cargando data EsSi para paciente: ${apeNomPac}`);

  const result = await db.cargarDataEsSi(
    apeNomPac, codHabCama, codHab, codCama, desEstCama,
    desSerCama, diashospi, fechaIngreso, nroDocIdePac,
    nroHisCliCas, tipoDocIdePac
  );
  return result[0].result;
}

async function editarNota(data, user) {
  const { id, nota, fecha_nota } = data;
  const usuario_id = user?.id || null;
  logger.debug(`Editando nota para cama: ${id} (usuario: ${usuario_id})`);
  const result = await db.editarNota(id, nota, fecha_nota, usuario_id);
  return result[0].result;
}

async function reconocerAlerta(data, user) {
  const { habitacion_id } = data;
  const usuario_id = user?.id || null;
  logger.debug(`Reconociendo alertas de habitacion: ${habitacion_id} (usuario: ${usuario_id})`);
  const result = await db.reconocerAlertasHabitacion(habitacion_id, usuario_id);
  const dbResult = result[0].result;

  // Publicar MQTT OFF: reconocer cancela todas las alertas de la habitacion
  if (dbResult.codigo === 200) {
    mqttService.publishAlerta(habitacion_id, 'OFF');
  }

  return dbResult;
}

async function cambiarCamaPaciente(data, user) {
  const { id_origen, id_destino, motivo } = data;
  const usuario_id = user?.id || null;
  logger.info(`Cambio manual de cama: ${id_origen} -> ${id_destino} (usuario: ${usuario_id})`);
  const result = await db.cambiarCamaPaciente(id_origen, id_destino, usuario_id, motivo || null);
  return result[0].result;
}

async function cancelarCambioManual(data, user) {
  const { id_cama } = data;
  const usuario_id = user?.id || null;
  logger.info(`Cancelar cambio manual: cama ${id_cama} (usuario: ${usuario_id})`);
  const result = await db.cancelarCambioManual(id_cama, usuario_id);
  return result[0].result;
}

async function ingresarPacienteManual(data, user) {
  const usuario_id = user?.id || null;
  logger.info(`Ingreso manual: DNI=${data.nro_doc_ide_pac} cama=${data.id_cama} (usuario: ${usuario_id})`);
  const result = await db.ingresarPacienteManual({
    id_cama: data.id_cama,
    nro_doc_ide_pac: data.nro_doc_ide_pac,
    tipo_doc_ide_pac: data.tipo_doc_ide_pac || 'DNI',
    ape_nom_pac: data.ape_nom_pac,
    nro_his_cli_cas: data.nro_his_cli_cas || null,
    des_ser_cama: data.des_ser_cama || null,
    fecha_salida_obligatoria: data.fecha_salida_obligatoria,
    pertenece_al_area: data.pertenece_al_area !== false,
    usuario_id,
    motivo: data.motivo || null,
  });
  return result[0].result;
}

async function buscarPacientePorDni(dni) {
  logger.debug(`Buscar paciente por DNI: ${dni}`);
  const result = await db.buscarPacientePorDni(dni);
  return result[0].result;
}

module.exports = {
  consultarHabitaciones,
  consultarHabitacionesEsSi,
  consultarAlertas,
  consultarInfoHabitaciones,
  cargarDataEsSi,
  editarNota,
  reconocerAlerta,
  cambiarCamaPaciente,
  cancelarCambioManual,
  ingresarPacienteManual,
  buscarPacientePorDni,
};