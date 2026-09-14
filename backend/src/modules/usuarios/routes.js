const express = require('express');
const controller = require('./controller');
const schemas = require('./schemas');
const response = require('../../utils/response');
const { auth, validateBody, authLimiter, asyncHandler } = require('../../middlewares');
const { requireRole } = require('../../middlewares/roleCheck');

const router = express.Router();

/**
 * POST /api/usuarios/login
 * Autenticación de usuario
 */
router.post(
  '/login',
  authLimiter,
  validateBody(schemas.loginSchema),
  asyncHandler(async (req, res) => {
    const result = await controller.login(req.body);

    if (result.estado === 'error') {
      return response.error(res, result.mensaje, result.codigo);
    }

    return response.success(res, result.mensaje, result.codigo);
  })
);

/**
 * POST /api/usuarios/refresh-token
 * Renovar token JWT (requiere token vigente)
 */
router.post(
  '/refresh-token',
  auth,
  asyncHandler(async (req, res) => {
    const result = await controller.refreshToken(req.user);

    if (result.estado === 'error') {
      return response.error(res, result.mensaje, result.codigo);
    }

    return response.success(res, result.mensaje, result.codigo);
  })
);

/**
 * POST /api/usuarios/registrar
 * Registrar nuevo usuario (requiere autenticación)
 */
router.post(
  '/registrar',
  auth,
  validateBody(schemas.registrarSchema),
  asyncHandler(async (req, res) => {
    const result = await controller.registrar(req.body);

    if (result.estado === 'error') {
      return response.error(res, result.mensaje, result.codigo);
    }

    // Incluir el id del usuario creado/actualizado en la respuesta
    const body = result.id
      ? { mensaje: result.mensaje, id: result.id }
      : result.mensaje;

    return response.success(res, body, result.codigo);
  })
);

/**
 * PUT /api/usuarios/eliminar
 * Eliminar usuario (requiere autenticación)
 */
router.put(
  '/eliminar',
  auth,
  validateBody(schemas.eliminarSchema),
  asyncHandler(async (req, res) => {
    const result = await controller.eliminar(req.body);

    if (result.estado === 'error') {
      return response.error(res, result.mensaje, result.codigo);
    }

    return response.success(res, result.mensaje, result.codigo);
  })
);

/**
 * POST /api/usuarios/asignar
 * Asignar usuario a área (requiere autenticación)
 */
router.post(
  '/asignar',
  auth,
  validateBody(schemas.asignarSchema),
  asyncHandler(async (req, res) => {
    const result = await controller.asignar(req.body);

    if (result.estado === 'error') {
      return response.error(res, result.mensaje, result.codigo);
    }

    return response.success(res, result.mensaje, result.codigo);
  })
);

/**
 * POST /api/usuarios/crear-area
 * Crear o buscar area hospitalaria (solo admin)
 */
router.post(
  '/crear-area',
  auth,
  requireRole('admin'),
  asyncHandler(async (req, res) => {
    const result = await controller.crearArea(req.body);

    if (result.estado === 'error') {
      return response.error(res, result.mensaje, result.codigo);
    }

    return response.success(res, result.mensaje, result.codigo);
  })
);

/**
 * GET /api/usuarios/listar
 * Listar todos los usuarios (solo admin)
 */
router.get(
  '/listar',
  auth,
  requireRole('admin'),
  asyncHandler(async (req, res) => {
    const result = await controller.listar();

    if (result.estado === 'error') {
      return response.error(res, result.mensaje, result.codigo);
    }

    return response.success(res, result.mensaje, result.codigo);
  })
);

/**
 * PUT /api/usuarios/cambiar-clave
 * Cambiar clave de un usuario (solo admin)
 */
router.put(
  '/cambiar-clave',
  auth,
  requireRole('admin'),
  validateBody(schemas.cambiarClaveSchema),
  asyncHandler(async (req, res) => {
    const result = await controller.cambiarClave(req.body);

    if (result.estado === 'error') {
      return response.error(res, result.mensaje, result.codigo);
    }

    return response.success(res, result.mensaje, result.codigo);
  })
);

/**
 * GET /api/usuarios/servicios-hospitalarios
 * Listar servicios hospitalarios con códigos EsSi (requiere auth)
 */
router.get(
  '/servicios-hospitalarios',
  auth,
  asyncHandler(async (req, res) => {
    const result = await controller.listarServicios();

    if (result.estado === 'error') {
      return response.error(res, result.mensaje, result.codigo);
    }

    return response.success(res, result.mensaje, result.codigo);
  })
);

/**
 * POST /api/usuarios/preview-sub-areas
 * Consultar sub-áreas (codHabCama) desde API externa EsSi
 */
router.post(
  '/preview-sub-areas',
  auth,
  requireRole('admin'),
  validateBody(schemas.previewSubAreasSchema),
  asyncHandler(async (req, res) => {
    const result = await controller.previewSubAreas(req.body);

    if (result.estado === 'error') {
      return response.error(res, result.mensaje, result.codigo);
    }

    return response.success(res, result.mensaje, result.codigo);
  })
);

/**
 * GET /api/usuarios/areas
 * Listar areas activas (requiere auth)
 */
router.get(
  '/areas',
  auth,
  asyncHandler(async (req, res) => {
    const result = await controller.listarAreas();

    if (result.estado === 'error') {
      return response.error(res, result.mensaje, result.codigo);
    }

    return response.success(res, result.mensaje, result.codigo);
  })
);

/**
 * PUT /api/usuarios/cambiar-mi-clave
 * Cambiar mi propia clave (cualquier usuario autenticado)
 */
router.put(
  '/cambiar-mi-clave',
  auth,
  validateBody(schemas.cambiarMiClaveSchema),
  asyncHandler(async (req, res) => {
    const result = await controller.cambiarMiClave(req.body, req.user.id);

    if (result.estado === 'error') {
      return response.error(res, result.mensaje, result.codigo);
    }

    return response.success(res, result.mensaje, result.codigo);
  })
);

module.exports = router;
