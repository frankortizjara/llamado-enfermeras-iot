const response = require('../utils/response');

/**
 * Middleware factory para validación de requests con Joi
 * @param {Object} schema - Esquema Joi para validar
 * @param {string} property - Propiedad del request a validar ('body', 'query', 'params')
 * @returns {Function} Middleware de Express
 */
const validate = (schema, property = 'body') => {
  return (req, res, next) => {
    const { error, value } = schema.validate(req[property], {
      abortEarly: false, // Mostrar todos los errores, no solo el primero
      stripUnknown: true, // Eliminar campos no definidos en el schema
    });

    if (error) {
      const errorMessages = error.details.map((detail) => detail.message).join('. ');
      return response.badRequest(res, errorMessages);
    }

    // Reemplazar con los valores validados (incluye conversiones de tipo)
    req[property] = value;
    next();
  };
};

/**
 * Valida el body del request
 */
const validateBody = (schema) => validate(schema, 'body');

/**
 * Valida los query params del request
 */
const validateQuery = (schema) => validate(schema, 'query');

/**
 * Valida los path params del request
 */
const validateParams = (schema) => validate(schema, 'params');

module.exports = {
  validate,
  validateBody,
  validateQuery,
  validateParams,
};
