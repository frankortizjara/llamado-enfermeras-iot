const db = require('../../database/pool');
const logger = require('../../utils/logger');

// ============================================
// EFEMÉRIDES
// ============================================

async function listarEfemerides() {
  logger.debug('Listando efemérides');
  const result = await db.listarEfemerides();
  return result[0].result;
}

async function agregarEfemeride(data) {
  const { id, titulo, descripcion, dia, mes, tipo, icono, estado } = data;
  logger.debug(`Guardando efeméride: ${titulo}`);
  const result = await db.agregarEfemeride(id || null, titulo, descripcion || null, dia, mes, tipo || 'salud', icono || null, estado !== undefined ? estado : true);
  return result[0].result;
}

async function eliminarEfemeride(id) {
  logger.debug(`Eliminando efeméride: ${id}`);
  const result = await db.eliminarEfemeride(id);
  return result[0].result;
}

// ============================================
// CUMPLEAÑOS
// ============================================

async function listarCumpleanos(area_id) {
  logger.debug(`Listando cumpleaños para área: ${area_id}`);
  const result = await db.listarCumpleanos(area_id || null);
  return result[0].result;
}

async function agregarCumpleano(data) {
  const { id, nombre, cargo, dia, mes, area_id, estado } = data;
  logger.debug(`Guardando cumpleaños: ${nombre}`);
  const result = await db.agregarCumpleano(id || null, nombre, cargo || null, dia, mes, area_id || null, estado !== undefined ? estado : true);
  return result[0].result;
}

async function eliminarCumpleano(id) {
  logger.debug(`Eliminando cumpleaños: ${id}`);
  const result = await db.eliminarCumpleano(id);
  return result[0].result;
}

// ============================================
// AVISOS
// ============================================

async function listarAvisos(area_id) {
  logger.debug(`Listando avisos para área: ${area_id}`);
  const result = await db.listarAvisos(area_id || null);
  return result[0].result;
}

async function agregarAviso(data, user) {
  const { id, titulo, mensaje, prioridad, area_id, fecha_inicio, fecha_fin, estado, modo_display } = data;
  const creado_por = user?.id || null;
  logger.debug(`Guardando aviso: ${titulo} (usuario: ${creado_por})`);
  const result = await db.agregarAviso(id || null, titulo, mensaje, prioridad || 'normal', area_id || null, creado_por, fecha_inicio || null, fecha_fin || null, estado !== undefined ? estado : true, modo_display || 'periodico');
  return result[0].result;
}

async function eliminarAviso(id) {
  logger.debug(`Eliminando aviso: ${id}`);
  const result = await db.eliminarAviso(id);
  return result[0].result;
}

// ============================================
// CONFIGURACIÓN TV
// ============================================

async function obtenerConfigTv() {
  logger.debug('Obteniendo configuración TV');
  const result = await db.obtenerConfigTv();
  return result[0].result;
}

async function actualizarConfigTv(data) {
  const { clave, valor } = data;
  logger.debug(`Actualizando config TV: ${clave} = ${valor}`);
  const result = await db.actualizarConfigTv(clave, valor);
  return result[0].result;
}

// ============================================
// CONTENIDO TV COMBINADO
// ============================================

async function obtenerContenidoTvHoy(data) {
  const { area_id } = data;
  const now = new Date();
  const dia = now.getDate();
  const mes = now.getMonth() + 1;
  logger.debug(`Obteniendo contenido TV para hoy (${dia}/${mes}) área: ${area_id}`);
  const result = await db.obtenerContenidoTv(dia, mes, area_id);
  return result[0].result;
}

// ============================================
// PANTALLAS TV
// ============================================

async function listarPantallasTv() {
  logger.debug('Listando pantallas TV');
  const result = await db.listarPantallasTv();
  return result[0].result;
}

async function agregarPantallaTv(data) {
  const { id, nombre, token, area_id, area_nombre, cod_hab_cama, estado } = data;
  logger.debug(`Guardando pantalla TV: ${nombre}`);
  const result = await db.agregarPantallaTv(
    id || null, nombre, token || null, area_id || null,
    area_nombre || null, cod_hab_cama || null,
    estado !== undefined ? estado : true
  );
  return result[0].result;
}

async function eliminarPantallaTv(id) {
  logger.debug(`Eliminando pantalla TV: ${id}`);
  const result = await db.eliminarPantallaTv(id);
  return result[0].result;
}

module.exports = {
  listarEfemerides,
  agregarEfemeride,
  eliminarEfemeride,
  listarCumpleanos,
  agregarCumpleano,
  eliminarCumpleano,
  listarAvisos,
  agregarAviso,
  eliminarAviso,
  obtenerConfigTv,
  actualizarConfigTv,
  obtenerContenidoTvHoy,
  listarPantallasTv,
  agregarPantallaTv,
  eliminarPantallaTv,
};
