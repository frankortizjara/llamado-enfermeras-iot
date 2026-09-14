const { authMiddleware, optionalAuth } = require('./auth');
const { errorHandler, notFoundHandler, asyncHandler } = require('./errorHandler');
const { validate, validateBody, validateQuery, validateParams } = require('./validateRequest');
const { globalLimiter, authLimiter } = require('./rateLimiter');
const { requireRole, requirePermission } = require('./roleCheck');

module.exports = {
  // Autenticación
  auth: authMiddleware,
  optionalAuth,

  // Roles y permisos
  requireRole,
  requirePermission,

  // Errores
  errorHandler,
  notFoundHandler,
  asyncHandler,

  // Validación
  validate,
  validateBody,
  validateQuery,
  validateParams,

  // Rate limiting
  globalLimiter,
  authLimiter,
};
