const jwt = require('jsonwebtoken');
const config = require('../config');

/**
 * Genera un token JWT
 * @param {Object} payload - Datos a incluir en el token (NO incluir contraseña)
 * @returns {string} Token JWT
 */
const generarToken = (payload) => {
  // Eliminar campos sensibles si existen
  const { clave, password, ...safePayload } = payload;

  return jwt.sign(safePayload, config.jwt.secret, {
    expiresIn: config.jwt.expiresIn,
  });
};

/**
 * Verifica y decodifica un token JWT
 * @param {string} token - Token a verificar
 * @returns {Object} Payload decodificado
 * @throws {Error} Si el token es inválido o expirado
 */
const verificarToken = (token) => {
  try {
    return jwt.verify(token, config.jwt.secret);
  } catch (error) {
    if (error.name === 'TokenExpiredError') {
      throw new Error('Token expirado');
    }
    if (error.name === 'JsonWebTokenError') {
      throw new Error('Token inválido');
    }
    throw error;
  }
};

/**
 * Extrae el token del header Authorization
 * @param {Object} req - Request de Express
 * @returns {string} Token extraído
 * @throws {Error} Si no hay token o el formato es incorrecto
 */
const extraerToken = (req) => {
  const authHeader = req.headers.authorization;

  if (!authHeader) {
    throw new Error('No se proporcionó token de autorización');
  }

  if (!authHeader.startsWith('Bearer ')) {
    throw new Error('Formato de token incorrecto. Use: Bearer <token>');
  }

  return authHeader.slice(7);
};

/**
 * Decodifica el token sin verificar (para debugging)
 * @param {string} token - Token a decodificar
 * @returns {Object} Payload decodificado
 */
const decodificarToken = (token) => {
  return jwt.decode(token);
};

module.exports = {
  generarToken,
  verificarToken,
  extraerToken,
  decodificarToken,
};
