const express = require('express');
const controller = require('./controller');
const response = require('../../utils/response');
const { asyncHandler } = require('../../middlewares');

const router = express.Router();

/**
 * GET /api/tv-publica/:token
 * Obtener configuración de pantalla TV por token (SIN autenticación)
 */
router.get(
  '/:token',
  asyncHandler(async (req, res) => {
    const { token } = req.params;
    if (!token || token.length < 8) {
      return response.badRequest(res, 'Token inválido');
    }

    const result = await controller.obtenerPantallaPorToken(token);

    if (result.estado === 'error') {
      return response.error(res, result.mensaje, result.codigo);
    }

    return response.success(res, result.mensaje, result.codigo);
  })
);

/**
 * GET /api/tv-publica/:token/habitaciones
 * Consultar habitaciones para una pantalla TV pública (SIN autenticación)
 */
router.get(
  '/:token/habitaciones',
  asyncHandler(async (req, res) => {
    const { token } = req.params;
    if (!token || token.length < 8) {
      return response.badRequest(res, 'Token inválido');
    }

    const result = await controller.consultarHabitacionesPorToken(token);

    if (result.estado === 'error') {
      return response.error(res, result.mensaje, result.codigo);
    }

    return response.success(res, result.mensaje, result.codigo);
  })
);

/**
 * GET /api/tv-publica/:token/alertas
 * Consultar alertas para una pantalla TV pública (SIN autenticación)
 */
router.get(
  '/:token/alertas',
  asyncHandler(async (req, res) => {
    const { token } = req.params;
    if (!token || token.length < 8) {
      return response.badRequest(res, 'Token inválido');
    }

    const result = await controller.consultarAlertasPorToken(token);

    if (result.estado === 'error') {
      return response.error(res, result.mensaje, result.codigo);
    }

    return response.success(res, result.mensaje, result.codigo);
  })
);

/**
 * GET /api/tv-publica/:token/contenido
 * Obtener contenido TV del día para pantalla pública (SIN autenticación)
 */
router.get(
  '/:token/contenido',
  asyncHandler(async (req, res) => {
    const { token } = req.params;
    if (!token || token.length < 8) {
      return response.badRequest(res, 'Token inválido');
    }

    const result = await controller.obtenerContenidoPorToken(token);

    if (result.estado === 'error') {
      return response.error(res, result.mensaje, result.codigo);
    }

    return response.success(res, result.mensaje, result.codigo);
  })
);

/**
 * GET /api/tv-publica/:token/config
 * Obtener configuración de audio/overlay para pantalla pública (SIN autenticación)
 */
router.get(
  '/:token/config',
  asyncHandler(async (req, res) => {
    const { token } = req.params;
    if (!token || token.length < 8) {
      return response.badRequest(res, 'Token inválido');
    }

    const result = await controller.obtenerConfigPorToken(token);

    if (result.estado === 'error') {
      return response.error(res, result.mensaje, result.codigo);
    }

    return response.success(res, result.mensaje, result.codigo);
  })
);

module.exports = router;
