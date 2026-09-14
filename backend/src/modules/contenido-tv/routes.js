const express = require('express');
const controller = require('./controller');
const schemas = require('./schemas');
const response = require('../../utils/response');
const { auth, requireRole, requirePermission, validateBody, asyncHandler } = require('../../middlewares');

const router = express.Router();

// ============================================
// EFEMÉRIDES
// ============================================

/**
 * GET /api/contenido-tv/efemerides
 * Listar todas las efemérides (requiere permiso contenido_tv_efemerides)
 */
router.get(
  '/efemerides',
  auth,
  requirePermission('contenido_tv_efemerides'),
  asyncHandler(async (req, res) => {
    const result = await controller.listarEfemerides();

    if (result.estado === 'error') {
      return response.error(res, result.mensaje, result.codigo);
    }

    return response.success(res, result.mensaje, result.codigo);
  })
);

/**
 * POST /api/contenido-tv/efemerides
 * Crear/editar efeméride (requiere permiso contenido_tv_efemerides)
 */
router.post(
  '/efemerides',
  auth,
  requirePermission('contenido_tv_efemerides'),
  validateBody(schemas.agregarEfemerideSchema),
  asyncHandler(async (req, res) => {
    const result = await controller.agregarEfemeride(req.body);

    if (result.estado === 'error') {
      return response.error(res, result.mensaje, result.codigo);
    }

    return response.success(res, result.mensaje, result.codigo);
  })
);

/**
 * DELETE /api/contenido-tv/efemerides/:id
 * Eliminar efeméride (requiere permiso contenido_tv_efemerides)
 */
router.delete(
  '/efemerides/:id',
  auth,
  requirePermission('contenido_tv_efemerides'),
  asyncHandler(async (req, res) => {
    const id = parseInt(req.params.id, 10);
    if (isNaN(id) || id <= 0) {
      return response.badRequest(res, 'ID inválido');
    }

    const result = await controller.eliminarEfemeride(id);

    if (result.estado === 'error') {
      return response.error(res, result.mensaje, result.codigo);
    }

    return response.success(res, result.mensaje, result.codigo);
  })
);

// ============================================
// CUMPLEAÑOS
// ============================================

/**
 * GET /api/contenido-tv/cumpleanos
 * Listar cumpleaños del área (requiere autenticación)
 */
router.get(
  '/cumpleanos',
  auth,
  asyncHandler(async (req, res) => {
    const area_id = req.user?.area_id || null;
    const result = await controller.listarCumpleanos(area_id);

    if (result.estado === 'error') {
      return response.error(res, result.mensaje, result.codigo);
    }

    return response.success(res, result.mensaje, result.codigo);
  })
);

/**
 * POST /api/contenido-tv/cumpleanos
 * Crear/editar cumpleaños (requiere autenticación)
 */
router.post(
  '/cumpleanos',
  auth,
  validateBody(schemas.agregarCumpleanoSchema),
  asyncHandler(async (req, res) => {
    const result = await controller.agregarCumpleano(req.body);

    if (result.estado === 'error') {
      return response.error(res, result.mensaje, result.codigo);
    }

    return response.success(res, result.mensaje, result.codigo);
  })
);

/**
 * DELETE /api/contenido-tv/cumpleanos/:id
 * Eliminar cumpleaños (requiere autenticación)
 */
router.delete(
  '/cumpleanos/:id',
  auth,
  asyncHandler(async (req, res) => {
    const id = parseInt(req.params.id, 10);
    if (isNaN(id) || id <= 0) {
      return response.badRequest(res, 'ID inválido');
    }

    const result = await controller.eliminarCumpleano(id);

    if (result.estado === 'error') {
      return response.error(res, result.mensaje, result.codigo);
    }

    return response.success(res, result.mensaje, result.codigo);
  })
);

// ============================================
// AVISOS
// ============================================

/**
 * GET /api/contenido-tv/avisos
 * Listar avisos activos del área (requiere autenticación)
 */
router.get(
  '/avisos',
  auth,
  asyncHandler(async (req, res) => {
    const area_id = req.user?.area_id || null;
    const result = await controller.listarAvisos(area_id);

    if (result.estado === 'error') {
      return response.error(res, result.mensaje, result.codigo);
    }

    return response.success(res, result.mensaje, result.codigo);
  })
);

/**
 * POST /api/contenido-tv/avisos
 * Crear/editar aviso (requiere permiso contenido_tv_avisos)
 */
router.post(
  '/avisos',
  auth,
  requirePermission('contenido_tv_avisos'),
  validateBody(schemas.agregarAvisoSchema),
  asyncHandler(async (req, res) => {
    const result = await controller.agregarAviso(req.body, req.user);

    if (result.estado === 'error') {
      return response.error(res, result.mensaje, result.codigo);
    }

    return response.success(res, result.mensaje, result.codigo);
  })
);

/**
 * DELETE /api/contenido-tv/avisos/:id
 * Eliminar aviso (requiere permiso contenido_tv_avisos)
 */
router.delete(
  '/avisos/:id',
  auth,
  requirePermission('contenido_tv_avisos'),
  asyncHandler(async (req, res) => {
    const id = parseInt(req.params.id, 10);
    if (isNaN(id) || id <= 0) {
      return response.badRequest(res, 'ID inválido');
    }

    const result = await controller.eliminarAviso(id);

    if (result.estado === 'error') {
      return response.error(res, result.mensaje, result.codigo);
    }

    return response.success(res, result.mensaje, result.codigo);
  })
);

// ============================================
// CONTENIDO TV COMBINADO
// ============================================

/**
 * POST /api/contenido-tv/hoy
 * Obtener contenido del día para TV (requiere autenticación)
 */
router.post(
  '/hoy',
  auth,
  validateBody(schemas.contenidoTvHoySchema),
  asyncHandler(async (req, res) => {
    const result = await controller.obtenerContenidoTvHoy(req.body);

    if (result.estado === 'error') {
      return response.error(res, result.mensaje, result.codigo);
    }

    return response.success(res, result.mensaje, result.codigo);
  })
);

// ============================================
// CONFIGURACIÓN TV
// ============================================

/**
 * GET /api/contenido-tv/config
 * Obtener configuración TV (requiere autenticación)
 */
router.get(
  '/config',
  auth,
  asyncHandler(async (req, res) => {
    const result = await controller.obtenerConfigTv();

    if (result.estado === 'error') {
      return response.error(res, result.mensaje, result.codigo);
    }

    return response.success(res, result.mensaje, result.codigo);
  })
);

/**
 * POST /api/contenido-tv/config
 * Actualizar configuración TV (requiere permiso contenido_tv_config)
 */
router.post(
  '/config',
  auth,
  requirePermission('contenido_tv_config'),
  asyncHandler(async (req, res) => {
    const { clave, valor } = req.body;
    if (!clave || valor === undefined) {
      return response.badRequest(res, 'Clave y valor son requeridos');
    }

    const result = await controller.actualizarConfigTv(req.body);

    if (result.estado === 'error') {
      return response.error(res, result.mensaje, result.codigo);
    }

    return response.success(res, result.mensaje, result.codigo);
  })
);

// ============================================
// PANTALLAS TV (CRUD admin)
// ============================================

/**
 * GET /api/contenido-tv/pantallas
 * Listar pantallas TV configuradas (requiere rol admin)
 */
router.get(
  '/pantallas',
  auth,
  requireRole('admin'),
  asyncHandler(async (req, res) => {
    const result = await controller.listarPantallasTv();

    if (result.estado === 'error') {
      return response.error(res, result.mensaje, result.codigo);
    }

    return response.success(res, result.mensaje, result.codigo);
  })
);

/**
 * POST /api/contenido-tv/pantallas
 * Crear/editar pantalla TV (requiere rol admin)
 */
router.post(
  '/pantallas',
  auth,
  requireRole('admin'),
  validateBody(schemas.agregarPantallaTvSchema),
  asyncHandler(async (req, res) => {
    // Si no viene area_id, usar el del usuario logueado
    if (!req.body.area_id && req.user?.area_id) {
      req.body.area_id = req.user.area_id;
    }

    const result = await controller.agregarPantallaTv(req.body);

    if (result.estado === 'error') {
      return response.error(res, result.mensaje, result.codigo);
    }

    return response.success(res, result.mensaje, result.codigo);
  })
);

/**
 * DELETE /api/contenido-tv/pantallas/:id
 * Eliminar pantalla TV (requiere rol admin)
 */
router.delete(
  '/pantallas/:id',
  auth,
  requireRole('admin'),
  asyncHandler(async (req, res) => {
    const id = parseInt(req.params.id, 10);
    if (isNaN(id) || id <= 0) {
      return response.badRequest(res, 'ID inválido');
    }

    const result = await controller.eliminarPantallaTv(id);

    if (result.estado === 'error') {
      return response.error(res, result.mensaje, result.codigo);
    }

    return response.success(res, result.mensaje, result.codigo);
  })
);

module.exports = router;
