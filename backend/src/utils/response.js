/**
 * Respuestas HTTP estandarizadas
 * Mantiene compatibilidad con el formato existente del frontend
 */

const success = (res, data, statusCode = 200) => {
  return res.status(statusCode).json({
    error: false,
    status: statusCode,
    body: data,
  });
};

const error = (res, message, statusCode = 500) => {
  return res.status(statusCode).json({
    error: true,
    status: statusCode,
    body: message,
  });
};

const created = (res, data) => {
  return success(res, data, 201);
};

const badRequest = (res, message = 'Solicitud inválida') => {
  return error(res, message, 400);
};

const unauthorized = (res, message = 'No autorizado') => {
  return error(res, message, 401);
};

const forbidden = (res, message = 'Acceso denegado') => {
  return error(res, message, 403);
};

const notFound = (res, message = 'Recurso no encontrado') => {
  return error(res, message, 404);
};

const conflict = (res, message = 'Conflicto con el recurso') => {
  return error(res, message, 409);
};

const tooManyRequests = (res, message = 'Demasiadas solicitudes') => {
  return error(res, message, 429);
};

const internalError = (res, message = 'Error interno del servidor') => {
  return error(res, message, 500);
};

module.exports = {
  success,
  error,
  created,
  badRequest,
  unauthorized,
  forbidden,
  notFound,
  conflict,
  tooManyRequests,
  internalError,
};
