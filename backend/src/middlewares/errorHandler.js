const logger = require('../utils/logger');
const response = require('../utils/response');
const config = require('../config');

/**
 * Middleware global de manejo de errores
 * Debe ser el último middleware registrado
 */
const errorHandler = (err, req, res, next) => {
  // Log del error
  logger.error(`Error: ${err.message}`, {
    stack: err.stack,
    path: req.path,
    method: req.method,
    ip: req.ip,
    userId: req.user?.id,
  });

  // Determinar código de estado
  const statusCode = err.statusCode || err.status || 500;

  // En producción, no mostrar detalles del error interno
  const message = config.isProduction && statusCode === 500
    ? 'Error interno del servidor'
    : err.message || 'Error interno del servidor';

  // Responder con formato estandarizado
  return response.error(res, message, statusCode);
};

/**
 * Middleware para rutas no encontradas
 */
const notFoundHandler = (req, res) => {
  logger.warn(`Ruta no encontrada: ${req.method} ${req.path}`);
  return response.notFound(res, `Ruta no encontrada: ${req.method} ${req.path}`);
};

/**
 * Wrapper para handlers async (captura errores automáticamente)
 */
const asyncHandler = (fn) => (req, res, next) => {
  Promise.resolve(fn(req, res, next)).catch(next);
};

module.exports = {
  errorHandler,
  notFoundHandler,
  asyncHandler,
};
