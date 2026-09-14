const express = require('express');
const controller = require('./controller');
const schemas = require('./schemas');
const response = require('../../utils/response');
const { auth, validateBody, validateQuery, asyncHandler } = require('../../middlewares');

const router = express.Router();

/**
 * POST /api/dispositivos/agregarESP32
 * Agregar o actualizar dispositivo ESP32 (requiere autenticación)
 */
router.post(
  '/agregarESP32',
  auth,
  validateBody(schemas.agregarESP32Schema),
  asyncHandler(async (req, res) => {
    const result = await controller.agregarESP32(req.body);

    if (result.estado === 'error') {
      return response.error(res, result.mensaje, result.codigo);
    }

    return response.success(res, result.mensaje, result.codigo);
  })
);

/**
 * POST /api/dispositivos/agregarRegistro
 * Agregar registro de alerta (requiere autenticación)
 */
router.post(
  '/agregarRegistro',
  auth,
  validateBody(schemas.agregarRegistroSchema),
  asyncHandler(async (req, res) => {
    const result = await controller.agregarRegistro(req.body);

    if (result.estado === 'error') {
      return response.error(res, result.mensaje, result.codigo);
    }

    return response.success(res, result.mensaje, result.codigo);
  })
);

/**
 * POST /api/dispositivos/heartbeat
 * Heartbeat de dispositivo ESP32 (SIN autenticacion)
 * El ESP32 envia su estado periodicamente
 */
router.post(
  '/heartbeat',
  validateBody(schemas.heartbeatSchema),
  asyncHandler(async (req, res) => {
    const result = await controller.heartbeat(req.body);

    if (result.estado === 'error') {
      return response.error(res, result.mensaje, result.codigo);
    }

    return response.success(res, result.mensaje, result.codigo);
  })
);

/**
 * GET /api/dispositivos/listar
 * Listar todos los dispositivos ESP32 con estado online (requiere autenticacion)
 */
router.get(
  '/listar',
  auth,
  asyncHandler(async (req, res) => {
    const result = await controller.listarDispositivos();

    if (result.estado === 'error') {
      return response.error(res, result.mensaje, result.codigo);
    }

    return response.success(res, result.mensaje, result.codigo);
  })
);

/**
 * GET /api/dispositivos/estadisticas
 * Estadisticas de dispositivos en rango de fechas (requiere autenticacion)
 */
router.get(
  '/estadisticas',
  auth,
  validateQuery(schemas.estadisticasQuerySchema),
  asyncHandler(async (req, res) => {
    const result = await controller.estadisticasDispositivos(req.query);

    if (result.estado === 'error') {
      return response.error(res, result.mensaje, result.codigo);
    }

    return response.success(res, result.mensaje, result.codigo);
  })
);

/**
 * GET /api/dispositivos/eventos/:serial
 * Eventos de un dispositivo especifico (requiere autenticacion)
 */
router.get(
  '/eventos/:serial',
  auth,
  validateQuery(schemas.eventosQuerySchema),
  asyncHandler(async (req, res) => {
    const { serial } = req.params;
    const result = await controller.eventosDispositivo({
      numero_serial: serial,
      ...req.query,
    });

    if (result.estado === 'error') {
      return response.error(res, result.mensaje, result.codigo);
    }

    return response.success(res, result.mensaje, result.codigo);
  })
);

// ============================================
// PURGA DE DATOS
// ============================================

/**
 * DELETE /api/dispositivos/purgar-eventos
 * Eliminar todos los eventos de conexion/desconexion (requiere autenticacion)
 */
router.delete(
  '/purgar-eventos',
  auth,
  asyncHandler(async (req, res) => {
    const result = await controller.purgarEventosDispositivos();

    if (result.estado === 'error') {
      return response.error(res, result.mensaje, result.codigo);
    }

    return response.success(res, result.mensaje, result.codigo);
  })
);

/**
 * DELETE /api/dispositivos/purgar-dispositivos
 * Eliminar todos los dispositivos ESP32 y sus eventos (requiere autenticacion)
 */
router.delete(
  '/purgar-dispositivos',
  auth,
  asyncHandler(async (req, res) => {
    const result = await controller.purgarDispositivosEsp32();

    if (result.estado === 'error') {
      return response.error(res, result.mensaje, result.codigo);
    }

    return response.success(res, result.mensaje, result.codigo);
  })
);

/**
 * DELETE /api/dispositivos/:id
 * Eliminar un dispositivo ESP32 individual (requiere autenticacion)
 */
router.delete(
  '/:id',
  auth,
  asyncHandler(async (req, res) => {
    const id = parseInt(req.params.id, 10);
    const result = await controller.eliminarDispositivo(id);

    if (result.estado === 'error') {
      return response.error(res, result.mensaje, result.codigo);
    }

    return response.success(res, result.mensaje, result.codigo);
  })
);

// ============================================
// CONTROLES RF
// ============================================

/**
 * GET /api/dispositivos/controles-rf
 * Listar controles RF configurados (requiere autenticacion)
 */
router.get(
  '/controles-rf',
  auth,
  asyncHandler(async (req, res) => {
    const result = await controller.listarControlesRf();

    if (result.estado === 'error') {
      return response.error(res, result.mensaje, result.codigo);
    }

    return response.success(res, result.mensaje, result.codigo);
  })
);

/**
 * POST /api/dispositivos/controles-rf
 * Agregar o editar control RF (requiere autenticacion)
 */
router.post(
  '/controles-rf',
  auth,
  validateBody(schemas.controlRfSchema),
  asyncHandler(async (req, res) => {
    const result = await controller.agregarControlRf(req.body);

    if (result.estado === 'error') {
      return response.error(res, result.mensaje, result.codigo);
    }

    return response.success(res, result.mensaje, result.codigo);
  })
);

/**
 * DELETE /api/dispositivos/controles-rf/:id
 * Eliminar control RF (requiere autenticacion)
 */
router.delete(
  '/controles-rf/:id',
  auth,
  asyncHandler(async (req, res) => {
    const id = parseInt(req.params.id, 10);
    const result = await controller.eliminarControlRf(id);

    if (result.estado === 'error') {
      return response.error(res, result.mensaje, result.codigo);
    }

    return response.success(res, result.mensaje, result.codigo);
  })
);

module.exports = router;