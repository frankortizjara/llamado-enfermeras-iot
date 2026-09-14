const { verificarToken, extraerToken } = require('../utils/jwt');
const response = require('../utils/response');
const logger = require('../utils/logger');

/**
 * Middleware de autenticación JWT
 * Verifica el token y agrega el usuario decodificado a req.user
 */
const authMiddleware = (req, res, next) => {
  try {
    const token = extraerToken(req);
    const decoded = verificarToken(token);
    req.user = decoded;
    next();
  } catch (error) {
    logger.warn(`Auth fallido: ${error.message} - IP: ${req.ip} - Path: ${req.path}`);
    return response.unauthorized(res, error.message);
  }
};

/**
 * Middleware opcional de autenticación
 * Si hay token, lo verifica. Si no hay, continúa sin usuario
 */
const optionalAuth = (req, res, next) => {
  try {
    const token = extraerToken(req);
    const decoded = verificarToken(token);
    req.user = decoded;
  } catch (error) {
    req.user = null;
  }
  next();
};

module.exports = {
  authMiddleware,
  optionalAuth,
};
