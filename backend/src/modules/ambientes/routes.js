const express = require('express');
const controller = require('./controller');
const schemas = require('./schemas');
const response = require('../../utils/response');
const { auth, validateBody, asyncHandler } = require('../../middlewares');

const router = express.Router();

/**
 * POST /api/ambientes/agregarArea
 * Agregar o actualizar área (requiere autenticación)
 */
router.post(
  '/agregarArea',
  auth,
  validateBody(schemas.agregarAreaSchema),
  asyncHandler(async (req, res) => {
    const result = await controller.agregarArea(req.body);

    if (result.estado === 'error') {
      return response.error(res, result.mensaje, result.codigo);
    }

    return response.success(res, result.mensaje, result.codigo);
  })
);

/**
 * POST /api/ambientes/agregarHabitacion
 * Agregar o actualizar habitación (requiere autenticación)
 */
router.post(
  '/agregarHabitacion',
  auth,
  validateBody(schemas.agregarHabitacionSchema),
  asyncHandler(async (req, res) => {
    const result = await controller.agregarHabitacion(req.body);

    if (result.estado === 'error') {
      return response.error(res, result.mensaje, result.codigo);
    }

    return response.success(res, result.mensaje, result.codigo);
  })
);

/**
 * POST /api/ambientes/agregarCama
 * Agregar o actualizar cama (requiere autenticación)
 */
router.post(
  '/agregarCama',
  auth,
  validateBody(schemas.agregarCamaSchema),
  asyncHandler(async (req, res) => {
    const result = await controller.agregarCama(req.body);

    if (result.estado === 'error') {
      return response.error(res, result.mensaje, result.codigo);
    }

    return response.success(res, result.mensaje, result.codigo);
  })
);

module.exports = router;
