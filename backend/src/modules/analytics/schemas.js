const Joi = require('joi');

const analyticsBaseSchema = Joi.object({
  area_id: Joi.number().integer().positive().required().messages({
    'number.base': 'El area_id debe ser un numero',
    'number.positive': 'El area_id debe ser positivo',
    'any.required': 'El area_id es requerido',
  }),
  fecha_inicio: Joi.string().required().messages({
    'string.empty': 'La fecha_inicio es requerida',
    'any.required': 'La fecha_inicio es requerida',
  }),
  fecha_fin: Joi.string().required().messages({
    'string.empty': 'La fecha_fin es requerida',
    'any.required': 'La fecha_fin es requerida',
  }),
});

module.exports = {
  analyticsBaseSchema,
};
