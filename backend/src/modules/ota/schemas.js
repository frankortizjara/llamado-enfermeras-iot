const Joi = require('joi');

/**
 * POST /api/ota/check
 * El ESP32 consulta si hay una nueva version disponible
 */
const checkSchema = Joi.object({
  numero_serial: Joi.string().max(12).required().messages({
    'string.empty': 'El numero_serial es requerido',
    'any.required': 'El numero_serial es requerido',
  }),
  firmware_version: Joi.string().max(20).required().messages({
    'string.empty': 'La firmware_version es requerida',
    'any.required': 'La firmware_version es requerida',
  }),
  tipo_dispositivo: Joi.string().valid('cuarto', 'bano', 'luces').required().messages({
    'any.only': 'tipo_dispositivo debe ser cuarto, bano o luces',
    'any.required': 'tipo_dispositivo es requerido',
  }),
  direccion_mac: Joi.string()
    .pattern(/^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$/)
    .optional(),
});

/**
 * POST /api/ota/upload
 * Subir un nuevo firmware .bin (solo validamos metadata en body)
 */
const uploadSchema = Joi.object({
  version: Joi.string().max(20).required().messages({
    'string.empty': 'La version es requerida',
    'any.required': 'La version es requerida',
  }),
  descripcion: Joi.string().max(500).allow('').default(''),
});

module.exports = {
  checkSchema,
  uploadSchema,
};
