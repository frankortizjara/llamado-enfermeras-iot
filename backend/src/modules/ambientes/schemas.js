const Joi = require('joi');

const agregarAreaSchema = Joi.object({
  id: Joi.number().integer().default(0),
  cod_ses: Joi.number().integer().positive().required().messages({
    'number.base': 'El cod_ses debe ser un numero',
    'number.positive': 'El cod_ses debe ser positivo',
    'any.required': 'El cod_ses es requerido',
  }),
  nombre: Joi.string().min(1).max(255).required().messages({
    'string.empty': 'El nombre es requerido',
    'string.max': 'El nombre no puede exceder 255 caracteres',
    'any.required': 'El nombre es requerido',
  }),
  estado: Joi.boolean().default(true),
});

const agregarHabitacionSchema = Joi.object({
  id: Joi.number().integer().default(0),
  area_id: Joi.number().integer().positive().required().messages({
    'number.base': 'El area_id debe ser un numero',
    'number.positive': 'El area_id debe ser positivo',
    'any.required': 'El area_id es requerido',
  }),
  nombre: Joi.number().integer().positive().required().messages({
    'number.base': 'El nombre debe ser un numero',
    'number.positive': 'El nombre debe ser positivo',
    'any.required': 'El nombre es requerido',
  }),
  estado: Joi.boolean().default(true),
});

const agregarCamaSchema = Joi.object({
  id: Joi.number().integer().default(0),
  habitacion_id: Joi.number().integer().positive().required().messages({
    'number.base': 'El habitacion_id debe ser un numero',
    'number.positive': 'El habitacion_id debe ser positivo',
    'any.required': 'El habitacion_id es requerido',
  }),
  nombre: Joi.string().min(1).max(255).required().messages({
    'string.empty': 'El nombre es requerido',
    'string.max': 'El nombre no puede exceder 255 caracteres',
    'any.required': 'El nombre es requerido',
  }),
  paciente: Joi.string().max(255).allow('').optional(),
  estado: Joi.boolean().default(true),
});

module.exports = {
  agregarAreaSchema,
  agregarHabitacionSchema,
  agregarCamaSchema,
};
