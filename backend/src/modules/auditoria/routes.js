const express = require('express');
const controller = require('./controller');
const schemas = require('./schemas');
const response = require('../../utils/response');
const { auth, requireRole, validateQuery, asyncHandler } = require('../../middlewares');

const router = express.Router();

/**
 * GET /api/auditoria/cambios
 * Lista paginada de eventos de historial_ocupacion con filtros.
 * Roles: admin, jefe_area, enfermera (todos los usuarios autenticados con rol valido).
 */
router.get(
  '/cambios',
  auth,
  requireRole('admin', 'jefe_area', 'enfermera'),
  validateQuery(schemas.listarAuditoriaQuerySchema),
  asyncHandler(async (req, res) => {
    const result = await controller.listar(req.query);
    if (result.estado === 'error') {
      return response.error(res, result.mensaje, result.codigo);
    }
    return response.success(res, result.mensaje, result.codigo);
  })
);

/**
 * GET /api/auditoria/exportar.csv
 * Descarga la auditoria filtrada en CSV (max 10000 filas).
 */
router.get(
  '/exportar.csv',
  auth,
  requireRole('admin', 'jefe_area', 'enfermera'),
  validateQuery(schemas.listarAuditoriaQuerySchema),
  asyncHandler(async (req, res) => {
    const { ok, csv, error } = await controller.exportarCsv(req.query);
    if (!ok) {
      return response.error(res, error.mensaje, error.codigo);
    }
    const filename = `auditoria_${new Date().toISOString().slice(0, 10)}.csv`;
    res.setHeader('Content-Type', 'text/csv; charset=utf-8');
    res.setHeader('Content-Disposition', `attachment; filename="${filename}"`);
    res.send(csv);
  })
);

module.exports = router;
