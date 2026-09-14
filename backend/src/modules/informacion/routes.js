const express = require('express');
const controller = require('./controller');
const schemas = require('./schemas');
const response = require('../../utils/response');
const { auth, requireRole, validateBody, asyncHandler } = require('../../middlewares');

const router = express.Router();

/**
 * POST /api/informacion/consultarHabitaciones
 * Consultar habitaciones del usuario (requiere autenticación)
 */
router.post(
  '/consultarHabitaciones',
  auth,
  validateBody(schemas.consultarHabitacionesSchema),
  asyncHandler(async (req, res) => {
    const result = await controller.consultarHabitaciones(req.body);

    if (result.estado === 'error') {
      return response.error(res, result.mensaje, result.codigo);
    }

    return response.success(res, result.mensaje, result.codigo);
  })
);

/**
 * POST /api/informacion/consultarHabitacionesEsSi
 * Consultar habitaciones desde sistema EsSi (requiere autenticación)
 */
router.post(
  '/consultarHabitacionesEsSi',
  auth,
  validateBody(schemas.consultarHabitacionesEsSiSchema),
  asyncHandler(async (req, res) => {
    const result = await controller.consultarHabitacionesEsSi(req.body);

    if (result.estado === 'error') {
      return response.error(res, result.mensaje, result.codigo);
    }

    return response.success(res, result.mensaje, result.codigo);
  })
);

/**
 * POST /api/informacion/consultarAlertas
 * Consultar alertas activas de un área (requiere autenticación)
 */
router.post(
  '/consultarAlertas',
  auth,
  validateBody(schemas.consultarAlertasSchema),
  asyncHandler(async (req, res) => {
    const result = await controller.consultarAlertas(req.body);

    if (result.estado === 'error') {
      return response.error(res, result.mensaje, result.codigo);
    }

    return response.success(res, result.mensaje, result.codigo);
  })
);

/**
 * POST /api/informacion/editarNota
 * Editar nota de una cama (requiere autenticación)
 */
router.post(
  '/editarNota',
  auth,
  validateBody(schemas.editarNotaSchema),
  asyncHandler(async (req, res) => {
    const result = await controller.editarNota(req.body, req.user);

    if (result.estado === 'error') {
      return response.error(res, result.mensaje, result.codigo);
    }

    return response.success(res, result.mensaje, result.codigo);
  })
);

/**
 * POST /api/informacion/cargarDataEsSi
 * Cargar datos de paciente desde EsSi (requiere autenticación)
 */
router.post(
  '/cargarDataEsSi',
  auth,
  validateBody(schemas.cargarDataEsSiSchema),
  asyncHandler(async (req, res) => {
    const result = await controller.cargarDataEsSi(req.body);

    if (result.estado === 'error') {
      return response.error(res, result.mensaje, result.codigo);
    }

    return response.success(res, result.mensaje, result.codigo);
  })
);

/**
 * POST /api/informacion/reconocerAlerta
 * Reconocer alertas de una habitacion (requiere rol jefe_area)
 */
router.post(
  '/reconocerAlerta',
  auth,
  requireRole('jefe_area'),
  validateBody(schemas.reconocerAlertaSchema),
  asyncHandler(async (req, res) => {
    const result = await controller.reconocerAlerta(req.body, req.user);

    if (result.estado === 'error') {
      return response.error(res, result.mensaje, result.codigo);
    }

    return response.success(res, result.mensaje, result.codigo);
  })
);

/**
 * POST /api/informacion/cambiarCamaPaciente
 * Mover o intercambiar paciente entre camas de la misma sub-area.
 * Roles: enfermera, jefe_area, admin.
 */
router.post(
  '/cambiarCamaPaciente',
  auth,
  requireRole('admin', 'jefe_area', 'enfermera'),
  validateBody(schemas.cambiarCamaPacienteSchema),
  asyncHandler(async (req, res) => {
    const result = await controller.cambiarCamaPaciente(req.body, req.user);

    if (result.estado === 'error') {
      return response.error(res, result.mensaje, result.codigo);
    }

    return response.success(res, result.mensaje, result.codigo);
  })
);

/**
 * POST /api/informacion/cancelarCambioManual
 * Cancela un cambio manual pendiente -- vuelve a confiar en EsSi.
 * Roles: enfermera, jefe_area, admin.
 */
router.post(
  '/cancelarCambioManual',
  auth,
  requireRole('admin', 'jefe_area', 'enfermera'),
  validateBody(schemas.cancelarCambioManualSchema),
  asyncHandler(async (req, res) => {
    const result = await controller.cancelarCambioManual(req.body, req.user);

    if (result.estado === 'error') {
      return response.error(res, result.mensaje, result.codigo);
    }

    return response.success(res, result.mensaje, result.codigo);
  })
);

/**
 * POST /api/informacion/ingresarPacienteManual
 * Ingresa manualmente un paciente en una cama LIBRE.
 * DNI y fecha_salida_obligatoria son obligatorios.
 * Roles: enfermera, jefe_area, admin.
 */
router.post(
  '/ingresarPacienteManual',
  auth,
  requireRole('admin', 'jefe_area', 'enfermera'),
  validateBody(schemas.ingresarPacienteManualSchema),
  asyncHandler(async (req, res) => {
    const result = await controller.ingresarPacienteManual(req.body, req.user);

    if (result.estado === 'error') {
      return response.error(res, result.mensaje, result.codigo);
    }

    return response.success(res, result.mensaje, result.codigo);
  })
);

/**
 * GET /api/informacion/buscarPacientePorDni/:dni
 * Devuelve el paciente si existe (para autocompletar en el modal de ingreso manual).
 * Roles: enfermera, jefe_area, admin.
 */
router.get(
  '/buscarPacientePorDni/:dni',
  auth,
  requireRole('admin', 'jefe_area', 'enfermera'),
  asyncHandler(async (req, res) => {
    const dni = String(req.params.dni || '').trim();
    if (!dni || dni.length > 20) {
      return response.badRequest(res, 'DNI invalido');
    }
    const result = await controller.buscarPacientePorDni(dni);
    if (result.estado === 'error') {
      return response.error(res, result.mensaje, result.codigo);
    }
    // codigo 404 con estado=success significa "no encontrado" -> devolver mensaje null
    return response.success(res, result.mensaje, result.codigo);
  })
);

module.exports = router;
