const express = require('express');
const controller = require('./controller');
const schemas = require('./schemas');
const response = require('../../utils/response');
const { auth, requirePermission, validateBody, asyncHandler } = require('../../middlewares');

const router = express.Router();

/**
 * POST /api/analytics/tiemposRespuesta
 * Tiempos de respuesta de alertas (requiere permiso analytics)
 */
router.post(
  '/tiemposRespuesta',
  auth,
  requirePermission('analytics'),
  validateBody(schemas.analyticsBaseSchema),
  asyncHandler(async (req, res) => {
    const result = await controller.tiemposRespuesta(req.body);

    if (result.estado === 'error') {
      return response.error(res, result.mensaje, result.codigo);
    }

    return response.success(res, result.mensaje, result.codigo);
  })
);

/**
 * POST /api/analytics/historialNotas
 * Historial de notas (requiere permiso analytics)
 */
router.post(
  '/historialNotas',
  auth,
  requirePermission('analytics'),
  validateBody(schemas.analyticsBaseSchema),
  asyncHandler(async (req, res) => {
    const result = await controller.historialNotas(req.body);

    if (result.estado === 'error') {
      return response.error(res, result.mensaje, result.codigo);
    }

    return response.success(res, result.mensaje, result.codigo);
  })
);

/**
 * POST /api/analytics/ocupacion
 * Ocupacion de camas (requiere permiso analytics)
 */
router.post(
  '/ocupacion',
  auth,
  requirePermission('analytics'),
  validateBody(schemas.analyticsBaseSchema),
  asyncHandler(async (req, res) => {
    const result = await controller.ocupacion(req.body);

    if (result.estado === 'error') {
      return response.error(res, result.mensaje, result.codigo);
    }

    return response.success(res, result.mensaje, result.codigo);
  })
);

/**
 * POST /api/analytics/frecuenciaAlertas
 * Frecuencia de alertas (requiere permiso analytics)
 */
router.post(
  '/frecuenciaAlertas',
  auth,
  requirePermission('analytics'),
  validateBody(schemas.analyticsBaseSchema),
  asyncHandler(async (req, res) => {
    const result = await controller.frecuenciaAlertas(req.body);

    if (result.estado === 'error') {
      return response.error(res, result.mensaje, result.codigo);
    }

    return response.success(res, result.mensaje, result.codigo);
  })
);

/**
 * DELETE /api/analytics/purgar
 * Eliminar datos de analytics del area (requiere permiso analytics)
 */
router.delete(
  '/purgar',
  auth,
  requirePermission('analytics'),
  asyncHandler(async (req, res) => {
    const result = await controller.purgarAnalytics({ area_id: req.user.area_id });

    if (result.estado === 'error') {
      return response.error(res, result.mensaje, result.codigo);
    }

    return response.success(res, result.mensaje, result.codigo);
  })
);

module.exports = router;
