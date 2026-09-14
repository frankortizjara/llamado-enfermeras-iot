const express = require('express');
const controller = require('./controller');
const schemas = require('./schemas');
const response = require('../../utils/response');
const { auth, requireRole, validateBody, asyncHandler } = require('../../middlewares');

const router = express.Router();

/**
 * GET /api/configuracion
 * Lista todas las claves de configuracion del sistema.
 * Lectura permitida a cualquier usuario autenticado (admin/jefe/enfermera).
 */
router.get(
  '/',
  auth,
  requireRole('admin', 'jefe_area', 'enfermera'),
  asyncHandler(async (req, res) => {
    const result = await controller.listar();
    if (result.estado === 'error') {
      return response.error(res, result.mensaje, result.codigo);
    }
    return response.success(res, result.mensaje, result.codigo);
  })
);

/**
 * GET /api/configuracion/:clave
 * Obtiene una clave especifica.
 */
router.get(
  '/:clave',
  auth,
  requireRole('admin', 'jefe_area', 'enfermera'),
  asyncHandler(async (req, res) => {
    const clave = String(req.params.clave || '').trim();
    if (!clave) {
      return response.badRequest(res, 'Clave invalida');
    }
    const result = await controller.obtener(clave);
    if (result.estado === 'error') {
      return response.error(res, result.mensaje, result.codigo);
    }
    return response.success(res, result.mensaje, result.codigo);
  })
);

/**
 * PUT /api/configuracion/:clave
 * Actualiza el valor de una clave. Solo administradores.
 * Si la clave es SYNC_INTERVAL_MINUTES, reprograma el cron sin reiniciar.
 */
router.put(
  '/:clave',
  auth,
  requireRole('admin'),
  validateBody(schemas.actualizarConfiguracionSchema),
  asyncHandler(async (req, res) => {
    const clave = String(req.params.clave || '').trim();
    if (!clave) {
      return response.badRequest(res, 'Clave invalida');
    }
    const usuario_id = req.user?.id ?? null;
    const result = await controller.actualizar(clave, req.body.valor, usuario_id);
    if (result.estado === 'error') {
      return response.error(res, result.mensaje, result.codigo);
    }
    return response.success(res, result.mensaje, result.codigo);
  })
);

module.exports = router;
