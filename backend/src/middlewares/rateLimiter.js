const rateLimit = require('express-rate-limit');
const config = require('../config');
const logger = require('../utils/logger');

/**
 * Rate limiter global
 * Limita el número de requests por IP en una ventana de tiempo
 */
const globalLimiter = rateLimit({
  windowMs: config.rateLimit.windowMs,
  max: config.rateLimit.max,
  message: {
    error: true,
    status: 429,
    body: 'Demasiadas solicitudes. Por favor, intente de nuevo mas tarde.',
  },
  standardHeaders: true,
  legacyHeaders: false,
  handler: (req, res, next, options) => {
    logger.warn(`Rate limit excedido - IP: ${req.ip} - Path: ${req.path}`);
    res.status(options.statusCode).json(options.message);
  },
});

/**
 * Rate limiter estricto para endpoints sensibles (login, registro)
 * Más restrictivo: 10 requests por 15 minutos
 */
const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutos
  max: 30,
  message: {
    error: true,
    status: 429,
    body: 'Demasiados intentos de autenticacion. Intente de nuevo en 15 minutos.',
  },
  standardHeaders: true,
  legacyHeaders: false,
  handler: (req, res, next, options) => {
    logger.warn(`Auth rate limit excedido - IP: ${req.ip}`);
    res.status(options.statusCode).json(options.message);
  },
});

module.exports = {
  globalLimiter,
  authLimiter,
};
