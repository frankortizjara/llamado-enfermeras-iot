const { Pool } = require('pg');
const config = require('../config');
const logger = require('../utils/logger');

const pool = new Pool({
  user: config.postgresql.user,
  host: config.postgresql.host,
  database: config.postgresql.database,
  password: config.postgresql.password,
  port: config.postgresql.port,
  max: config.postgresql.max,
  idleTimeoutMillis: config.postgresql.idleTimeoutMillis,
  connectionTimeoutMillis: config.postgresql.connectionTimeoutMillis,
});

// Manejo de errores del pool
pool.on('error', (err) => {
  logger.error('Error inesperado en el pool de PostgreSQL', err);
});

/**
 * Conectar a PostgreSQL con retry y backoff exponencial
 */
const MAX_RETRIES = 5;
const INITIAL_DELAY = 200;

async function conectar(retryCount = 0) {
  try {
    const client = await pool.connect();
    logger.info('Conexion a PostgreSQL exitosa');
    client.release();
    return true;
  } catch (error) {
    if (retryCount >= MAX_RETRIES) {
      logger.error(`Error fatal: No se pudo conectar a PostgreSQL despues de ${MAX_RETRIES} intentos`);
      throw error;
    }

    const delay = INITIAL_DELAY * Math.pow(2, retryCount);
    logger.warn(`Error conectando a PostgreSQL. Reintentando en ${delay}ms... (intento ${retryCount + 1}/${MAX_RETRIES})`);

    await new Promise((resolve) => setTimeout(resolve, delay));
    return conectar(retryCount + 1);
  }
}

/**
 * Cerrar el pool de conexiones (para graceful shutdown)
 */
async function cerrar() {
  logger.info('Cerrando pool de conexiones PostgreSQL...');
  await pool.end();
  logger.info('Pool de conexiones cerrado');
}

// Graceful shutdown
process.on('SIGTERM', async () => {
  await cerrar();
  process.exit(0);
});

process.on('SIGINT', async () => {
  await cerrar();
  process.exit(0);
});

// ============================================
// FUNCIONES DE DISPOSITIVOS
// ============================================

async function agregarESP32(numero_serial, direccion_mac, ip_wifi, estado) {
  const result = await pool.query(
    'SELECT * FROM public.sp_agregar_esp32($1, $2, $3, $4) AS result',
    [numero_serial, direccion_mac, ip_wifi, estado]
  );
  return result.rows;
}

async function agregarRegistro(numero_serial, area_id, habitacion_id, codigo_cama, tipo_alerta) {
  const result = await pool.query(
    'SELECT * FROM public.sp_agregar_registro($1, $2, $3, $4, $5) AS result',
    [numero_serial, area_id, habitacion_id, codigo_cama, tipo_alerta]
  );
  return result.rows;
}

async function heartbeatDispositivo(numero_serial, direccion_mac, ip, tipo_dispositivo, habitacion_id, relay_estado, uptime, rssi) {
  const result = await pool.query(
    'SELECT * FROM public.sp_heartbeat_dispositivo($1, $2, $3, $4, $5, $6, $7, $8) AS result',
    [numero_serial, direccion_mac, ip, tipo_dispositivo, habitacion_id, relay_estado, uptime, rssi]
  );
  return result.rows;
}

async function listarDispositivos() {
  const result = await pool.query(
    'SELECT * FROM public.sp_listar_dispositivos() AS result'
  );
  return result.rows;
}

async function estadisticasDispositivos(fecha_inicio, fecha_fin) {
  const result = await pool.query(
    'SELECT * FROM public.sp_estadisticas_dispositivos($1, $2) AS result',
    [fecha_inicio, fecha_fin]
  );
  return result.rows;
}

async function eventosDispositivo(numero_serial, fecha_inicio, fecha_fin) {
  const result = await pool.query(
    'SELECT * FROM public.sp_eventos_dispositivo($1, $2, $3) AS result',
    [numero_serial, fecha_inicio, fecha_fin]
  );
  return result.rows;
}

// ============================================
// FUNCIONES DE CONTROLES RF
// ============================================

async function listarControlesRf() {
  const result = await pool.query(
    'SELECT * FROM public.sp_listar_controles_rf() AS result'
  );
  return result.rows;
}

async function agregarControlRf(id, habitacion_id, cama, dip_config, descripcion, estado) {
  const result = await pool.query(
    'SELECT * FROM public.sp_agregar_control_rf($1, $2, $3, $4::jsonb, $5, $6) AS result',
    [id, habitacion_id, cama, JSON.stringify(dip_config), descripcion, estado]
  );
  return result.rows;
}

async function eliminarControlRf(id) {
  const result = await pool.query(
    'SELECT * FROM public.sp_eliminar_control_rf($1) AS result',
    [id]
  );
  return result.rows;
}

// ============================================
// FUNCIONES DE INFORMACION
// ============================================

async function consultarHabitaciones(id) {
  const result = await pool.query(
    'SELECT * FROM public.sp_consultar_habitaciones($1) AS result',
    [id]
  );
  return result.rows;
}

async function consultarHabitacionesEsSi(codHabCama) {
  const result = await pool.query(
    'SELECT * FROM public.sp_consultar_habitaciones_essi($1) AS result',
    [codHabCama]
  );
  return result.rows;
}

async function consultarAlertas(area_id) {
  const result = await pool.query(
    'SELECT * FROM public.sp_consultar_alertas($1) AS result',
    [area_id]
  );
  return result.rows;
}

async function consultarInfoHabitaciones() {
  const result = await pool.query(
    'SELECT * FROM public.sp_consultar_info_habitaciones() AS result'
  );
  return result.rows;
}

async function cargarDataEsSi(apeNomPac, codHabCama, codHab, codCama, desEstCama, desSerCama, diashospi, fechaIngreso, nroDocIdePac, nroHisCliCas, tipoDocIdePac) {
  const result = await pool.query(
    'SELECT * FROM public.sp_cargar_data_essi($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11) AS result',
    [apeNomPac, codHabCama, codHab, codCama, desEstCama, desSerCama, diashospi, fechaIngreso, nroDocIdePac, nroHisCliCas, tipoDocIdePac]
  );
  return result.rows;
}

async function editarNota(id, nota, fecha_nota, usuario_id = null) {
  const result = await pool.query(
    'SELECT * FROM public.sp_editar_nota($1, $2, $3, $4) AS result',
    [id, nota, fecha_nota, usuario_id]
  );
  return result.rows;
}

// ============================================
// FUNCIONES DE AMBIENTES
// ============================================

async function agregarArea(id, cod_ses, nombre, estado) {
  const result = await pool.query(
    'SELECT * FROM public.sp_agregar_area($1, $2, $3, $4) AS result',
    [id, cod_ses, nombre, estado]
  );
  return result.rows;
}

async function agregarHabitacion(id, area_id, nombre, estado) {
  const result = await pool.query(
    'SELECT * FROM public.sp_agregar_habitacion($1, $2, $3, $4) AS result',
    [id, area_id, nombre, estado]
  );
  return result.rows;
}

async function agregarCama(id, habitacion_id, nombre, paciente, estado) {
  const result = await pool.query(
    'SELECT * FROM public.sp_agregar_cama($1, $2, $3, $4, $5) AS result',
    [id, habitacion_id, nombre, paciente, estado]
  );
  return result.rows;
}

// ============================================
// FUNCIONES DE USUARIOS
// ============================================

async function registrarUsuario(id, nombre, usuario, clave, estado) {
  const result = await pool.query(
    'SELECT * FROM public.sp_registrar_usuario($1, $2, $3, $4, $5) AS result',
    [id, nombre, usuario, clave, estado]
  );
  return result.rows;
}

async function eliminarUsuario(id) {
  const result = await pool.query(
    'SELECT * FROM public.sp_eliminar_usuario($1) AS result',
    [id]
  );
  return result.rows;
}

async function asignarUsuario(id, usuario_id, area_id, rol, estado, permisos = {}) {
  const result = await pool.query(
    'SELECT * FROM public.sp_asignar_usuario($1, $2, $3, $4, $5, $6::jsonb) AS result',
    [id, usuario_id, area_id, rol, estado, JSON.stringify(permisos)]
  );
  return result.rows;
}

async function login(usuario) {
  const result = await pool.query(
    'SELECT * FROM public.sp_obtener_usuario($1) AS result',
    [usuario]
  );
  return result.rows;
}

async function listarUsuarios() {
  const result = await pool.query(
    'SELECT * FROM public.sp_listar_usuarios() AS result'
  );
  return result.rows;
}

async function cambiarClave(id, clave) {
  const result = await pool.query(
    'SELECT * FROM public.sp_cambiar_clave($1, $2) AS result',
    [id, clave]
  );
  return result.rows;
}

async function listarServiciosHospitalarios() {
  const result = await pool.query(
    'SELECT * FROM public.sp_listar_servicios_hospitalarios() AS result'
  );
  return result.rows;
}

// ============================================
// VERIFICAR ALERTAS ACTIVAS (para MQTT)
// ============================================

async function contarAlertasActivas(habitacion_id) {
  const result = await pool.query(
    'SELECT COUNT(*) as total FROM alertas WHERE habitacion_id = $1 AND estado_alerta = TRUE',
    [habitacion_id]
  );
  return parseInt(result.rows[0].total, 10);
}

// ============================================
// FUNCIONES DE RECONOCIMIENTO DE ALERTAS
// ============================================

async function reconocerAlertasHabitacion(habitacion_id, usuario_id) {
  const result = await pool.query(
    'SELECT * FROM public.sp_reconocer_alertas_habitacion($1, $2) AS result',
    [habitacion_id, usuario_id]
  );
  return result.rows;
}

// ============================================
// FUNCIONES DE CONTENIDO TV (Efemérides, Cumpleaños, Avisos)
// ============================================

// Efemérides
async function listarEfemerides() {
  const result = await pool.query(
    'SELECT * FROM public.sp_listar_efemerides() AS result'
  );
  return result.rows;
}

async function obtenerEfemeridesHoy(dia, mes) {
  const result = await pool.query(
    'SELECT * FROM public.sp_obtener_efemerides_hoy($1, $2) AS result',
    [dia, mes]
  );
  return result.rows;
}

async function agregarEfemeride(id, titulo, descripcion, dia, mes, tipo, icono, estado) {
  const result = await pool.query(
    'SELECT * FROM public.sp_agregar_efemeride($1, $2, $3, $4, $5, $6, $7, $8) AS result',
    [id, titulo, descripcion, dia, mes, tipo, icono, estado]
  );
  return result.rows;
}

async function eliminarEfemeride(id) {
  const result = await pool.query(
    'SELECT * FROM public.sp_eliminar_efemeride($1) AS result',
    [id]
  );
  return result.rows;
}

// Cumpleaños
async function listarCumpleanos(area_id) {
  const result = await pool.query(
    'SELECT * FROM public.sp_listar_cumpleanos($1) AS result',
    [area_id]
  );
  return result.rows;
}

async function obtenerCumpleanosHoy(dia, mes, area_id) {
  const result = await pool.query(
    'SELECT * FROM public.sp_obtener_cumpleanos_hoy($1, $2, $3) AS result',
    [dia, mes, area_id]
  );
  return result.rows;
}

async function agregarCumpleano(id, nombre, cargo, dia, mes, area_id, estado) {
  const result = await pool.query(
    'SELECT * FROM public.sp_agregar_cumpleano($1, $2, $3, $4, $5, $6, $7) AS result',
    [id, nombre, cargo, dia, mes, area_id, estado]
  );
  return result.rows;
}

async function eliminarCumpleano(id) {
  const result = await pool.query(
    'SELECT * FROM public.sp_eliminar_cumpleano($1) AS result',
    [id]
  );
  return result.rows;
}

// Avisos
async function listarAvisos(area_id) {
  const result = await pool.query(
    'SELECT * FROM public.sp_listar_avisos($1) AS result',
    [area_id]
  );
  return result.rows;
}

async function agregarAviso(id, titulo, mensaje, prioridad, area_id, creado_por, fecha_inicio, fecha_fin, estado, modo_display) {
  const result = await pool.query(
    'SELECT * FROM public.sp_agregar_aviso($1, $2, $3, $4, $5, $6, $7, $8, $9, $10) AS result',
    [id, titulo, mensaje, prioridad, area_id, creado_por, fecha_inicio, fecha_fin, estado, modo_display]
  );
  return result.rows;
}

// Configuración TV
async function obtenerConfigTv() {
  const result = await pool.query(
    'SELECT * FROM public.sp_obtener_config_tv() AS result'
  );
  return result.rows;
}

async function actualizarConfigTv(clave, valor) {
  const result = await pool.query(
    'SELECT * FROM public.sp_actualizar_config_tv($1, $2) AS result',
    [clave, valor]
  );
  return result.rows;
}

async function eliminarAviso(id) {
  const result = await pool.query(
    'SELECT * FROM public.sp_eliminar_aviso($1) AS result',
    [id]
  );
  return result.rows;
}

// Pantallas TV
async function listarPantallasTv() {
  const result = await pool.query(
    'SELECT * FROM public.sp_listar_pantallas_tv() AS result'
  );
  return result.rows;
}

async function agregarPantallaTv(id, nombre, token, area_id, area_nombre, cod_hab_cama, estado) {
  const result = await pool.query(
    'SELECT * FROM public.sp_agregar_pantalla_tv($1, $2, $3, $4, $5, $6, $7) AS result',
    [id, nombre, token, area_id, area_nombre, cod_hab_cama, estado]
  );
  return result.rows;
}

async function eliminarPantallaTv(id) {
  const result = await pool.query(
    'SELECT * FROM public.sp_eliminar_pantalla_tv($1) AS result',
    [id]
  );
  return result.rows;
}

async function obtenerPantallaTvPorToken(token) {
  const result = await pool.query(
    'SELECT * FROM public.sp_obtener_pantalla_tv_por_token($1) AS result',
    [token]
  );
  return result.rows;
}

// Contenido TV combinado
async function obtenerContenidoTv(dia, mes, area_id) {
  const result = await pool.query(
    'SELECT * FROM public.sp_obtener_contenido_tv($1, $2, $3) AS result',
    [dia, mes, area_id]
  );
  return result.rows;
}

// ============================================
// FUNCIONES DE PURGA DE DATOS
// ============================================

async function purgarEventosDispositivos() {
  const client = await pool.connect();
  try {
    const res = await client.query('DELETE FROM dispositivo_eventos');
    return [{ result: { estado: 'success', codigo: 200, mensaje: `Se eliminaron ${res.rowCount} eventos de dispositivos` } }];
  } catch (err) {
    return [{ result: { estado: 'error', codigo: 500, mensaje: err.message } }];
  } finally {
    client.release();
  }
}

async function purgarDispositivosEsp32() {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const evRes = await client.query('DELETE FROM dispositivo_eventos');
    await client.query('DELETE FROM alertas WHERE dispositivo_id IN (SELECT id FROM esp32_dispositivos)');
    const dispRes = await client.query('DELETE FROM esp32_dispositivos');
    await client.query('COMMIT');
    return [{ result: { estado: 'success', codigo: 200, mensaje: `Se eliminaron ${dispRes.rowCount} dispositivos y ${evRes.rowCount} eventos` } }];
  } catch (err) {
    await client.query('ROLLBACK');
    return [{ result: { estado: 'error', codigo: 500, mensaje: err.message } }];
  } finally {
    client.release();
  }
}

async function eliminarDispositivoPorId(dispositivo_id) {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await client.query('DELETE FROM dispositivo_eventos WHERE dispositivo_id = $1', [dispositivo_id]);
    await client.query('DELETE FROM alertas WHERE dispositivo_id = $1', [dispositivo_id]);
    await client.query('DELETE FROM esp32_dispositivos WHERE id = $1', [dispositivo_id]);
    await client.query('COMMIT');
    return [{ result: { estado: 'success', codigo: 200, mensaje: 'Dispositivo eliminado' } }];
  } catch (err) {
    await client.query('ROLLBACK');
    return [{ result: { estado: 'error', codigo: 500, mensaje: err.message } }];
  } finally {
    client.release();
  }
}

async function purgarAnalytics(area_id) {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    // Obtener nombre del area
    const areaRes = await client.query('SELECT nombre FROM areas WHERE id = $1', [area_id]);
    if (areaRes.rows.length === 0) {
      await client.query('ROLLBACK');
      return [{ result: { estado: 'error', codigo: 404, mensaje: 'Area no encontrada' } }];
    }
    const areaNombre = areaRes.rows[0].nombre;

    const alertasRes = await client.query('DELETE FROM historial_alertas WHERE area_id = $1', [area_id]);
    const notasRes = await client.query('DELETE FROM historial_notas WHERE codhabcama = $1', [areaNombre]);
    const ocupRes = await client.query('DELETE FROM historial_ocupacion WHERE codhabcama = $1', [areaNombre]);
    await client.query('COMMIT');

    return [{ result: { estado: 'success', codigo: 200, mensaje: `Se eliminaron ${alertasRes.rowCount} alertas, ${notasRes.rowCount} notas y ${ocupRes.rowCount} registros de ocupacion` } }];
  } catch (err) {
    await client.query('ROLLBACK');
    return [{ result: { estado: 'error', codigo: 500, mensaje: err.message } }];
  } finally {
    client.release();
  }
}

// ============================================
// FUNCIONES DE ANALYTICS
// ============================================

async function analyticsTiemposRespuesta(area_id, fecha_inicio, fecha_fin) {
  const result = await pool.query(
    'SELECT * FROM public.sp_analytics_tiempos_respuesta($1, $2, $3) AS result',
    [area_id, fecha_inicio, fecha_fin]
  );
  return result.rows;
}

async function analyticsHistorialNotas(area_id, fecha_inicio, fecha_fin) {
  const result = await pool.query(
    'SELECT * FROM public.sp_analytics_historial_notas($1, $2, $3) AS result',
    [area_id, fecha_inicio, fecha_fin]
  );
  return result.rows;
}

async function analyticsOcupacion(area_id, fecha_inicio, fecha_fin) {
  const result = await pool.query(
    'SELECT * FROM public.sp_analytics_ocupacion($1, $2, $3) AS result',
    [area_id, fecha_inicio, fecha_fin]
  );
  return result.rows;
}

// =====================================================
// Gestion manual de camas (Fase 1)
// =====================================================

async function cambiarCamaPaciente(id_origen, id_destino, usuario_id, motivo = null) {
  const result = await pool.query(
    'SELECT * FROM public.sp_cambiar_cama_paciente($1, $2, $3, $4) AS result',
    [id_origen, id_destino, usuario_id, motivo]
  );
  return result.rows;
}

async function cancelarCambioManual(id_cama, usuario_id) {
  const result = await pool.query(
    'SELECT * FROM public.sp_cancelar_cambio_manual($1, $2) AS result',
    [id_cama, usuario_id]
  );
  return result.rows;
}

async function ingresarPacienteManual(params) {
  const {
    id_cama,
    nro_doc_ide_pac,
    tipo_doc_ide_pac = 'DNI',
    ape_nom_pac,
    nro_his_cli_cas = null,
    des_ser_cama = null,
    fecha_salida_obligatoria,
    pertenece_al_area = true,
    usuario_id = null,
    motivo = null,
  } = params;

  const result = await pool.query(
    `SELECT * FROM public.sp_ingresar_paciente_manual($1,$2,$3,$4,$5,$6,$7,$8,$9,$10) AS result`,
    [id_cama, nro_doc_ide_pac, tipo_doc_ide_pac, ape_nom_pac, nro_his_cli_cas,
     des_ser_cama, fecha_salida_obligatoria, pertenece_al_area, usuario_id, motivo]
  );
  return result.rows;
}

async function buscarPacientePorDni(dni) {
  const result = await pool.query(
    'SELECT * FROM public.sp_buscar_paciente_por_dni($1) AS result',
    [dni]
  );
  return result.rows;
}

async function procesarManualesExpirados() {
  const result = await pool.query(
    'SELECT * FROM public.sp_procesar_manuales_expirados() AS result'
  );
  return result.rows;
}

async function listarAuditoria(filtros = {}) {
  const {
    desde = null,
    hasta = null,
    usuario_id = null,
    accion = null,
    area_id = null,
    limit = 50,
    offset = 0,
  } = filtros;

  const result = await pool.query(
    'SELECT * FROM public.sp_listar_auditoria($1, $2, $3, $4, $5, $6, $7) AS result',
    [desde, hasta, usuario_id, accion, area_id, limit, offset]
  );
  return result.rows;
}

// =====================================================
// Configuracion del sistema (Fase 0)
// =====================================================

async function listarConfiguracionSistema() {
  const result = await pool.query(
    'SELECT * FROM public.sp_listar_configuracion() AS result'
  );
  return result.rows;
}

async function obtenerConfiguracionSistema(clave) {
  const result = await pool.query(
    'SELECT * FROM public.sp_obtener_configuracion($1) AS result',
    [clave]
  );
  return result.rows;
}

async function actualizarConfiguracionSistema(clave, valor, usuario_id = null) {
  const result = await pool.query(
    'SELECT * FROM public.sp_actualizar_configuracion($1, $2, $3) AS result',
    [clave, valor, usuario_id]
  );
  return result.rows;
}

/**
 * Lectura directa del valor de una clave de configuracion (sin envolver en SP).
 * Pensada para uso desde jobs/cron donde solo importa el valor.
 * Devuelve string o null si no existe.
 */
async function leerValorConfiguracion(clave) {
  const result = await pool.query(
    'SELECT valor FROM public.configuracion_sistema WHERE clave = $1 LIMIT 1',
    [clave]
  );
  return result.rows[0]?.valor ?? null;
}

async function analyticsFrecuenciaAlertas(area_id, fecha_inicio, fecha_fin) {
  const result = await pool.query(
    'SELECT * FROM public.sp_analytics_frecuencia_alertas($1, $2, $3) AS result',
    [area_id, fecha_inicio, fecha_fin]
  );
  return result.rows;
}

module.exports = {
  // Pool management
  pool,
  conectar,
  testConnection: conectar, // Alias para compatibilidad con index.js
  cerrar,
  closePool: cerrar, // Alias para compatibilidad con index.js

  // Dispositivos
  agregarESP32,
  agregarRegistro,
  heartbeatDispositivo,
  listarDispositivos,
  estadisticasDispositivos,
  eventosDispositivo,

  // Controles RF
  listarControlesRf,
  agregarControlRf,
  eliminarControlRf,

  // Informacion
  consultarHabitaciones,
  consultarHabitacionesEsSi,
  consultarAlertas,
  consultarInfoHabitaciones,
  cargarDataEsSi,
  editarNota,

  // Alertas activas (MQTT)
  contarAlertasActivas,

  // Reconocimiento de alertas
  reconocerAlertasHabitacion,

  // Purga de datos
  purgarEventosDispositivos,
  purgarDispositivosEsp32,
  eliminarDispositivoPorId,
  purgarAnalytics,

  // Analytics
  analyticsTiemposRespuesta,
  analyticsHistorialNotas,
  analyticsOcupacion,
  analyticsFrecuenciaAlertas,

  // Contenido TV
  listarEfemerides,
  obtenerEfemeridesHoy,
  agregarEfemeride,
  eliminarEfemeride,
  listarCumpleanos,
  obtenerCumpleanosHoy,
  agregarCumpleano,
  eliminarCumpleano,
  listarAvisos,
  agregarAviso,
  eliminarAviso,
  obtenerContenidoTv,
  obtenerConfigTv,
  actualizarConfigTv,

  // Pantallas TV
  listarPantallasTv,
  agregarPantallaTv,
  eliminarPantallaTv,
  obtenerPantallaTvPorToken,

  // Ambientes
  agregarArea,
  agregarHabitacion,
  agregarCama,

  // Usuarios
  registrarUsuario,
  eliminarUsuario,
  asignarUsuario,
  login,
  listarUsuarios,
  cambiarClave,

  // Servicios hospitalarios
  listarServiciosHospitalarios,

  // Configuracion del sistema (Fase 0)
  listarConfiguracionSistema,
  obtenerConfiguracionSistema,
  actualizarConfiguracionSistema,
  leerValorConfiguracion,

  // Gestion manual de camas (Fase 1)
  cambiarCamaPaciente,
  cancelarCambioManual,
  listarAuditoria,

  // Ingreso manual y cron secundario (Fase 2)
  ingresarPacienteManual,
  buscarPacientePorDni,
  procesarManualesExpirados,
};
