const Joi = require('joi');

const agregarEfemerideSchema = Joi.object({
  id: Joi.number().integer().positive().allow(null).optional(),
  titulo: Joi.string().max(255).required().messages({
    'string.empty': 'El título es requerido',
    'any.required': 'El título es requerido',
  }),
  descripcion: Joi.string().allow('', null).optional(),
  dia: Joi.number().integer().min(1).max(31).required().messages({
    'number.min': 'El día debe ser entre 1 y 31',
    'number.max': 'El día debe ser entre 1 y 31',
    'any.required': 'El día es requerido',
  }),
  mes: Joi.number().integer().min(1).max(12).required().messages({
    'number.min': 'El mes debe ser entre 1 y 12',
    'number.max': 'El mes debe ser entre 1 y 12',
    'any.required': 'El mes es requerido',
  }),
  tipo: Joi.string().valid('salud', 'internacional', 'peru').default('salud'),
  icono: Joi.string().max(100).allow('', null).optional(),
  estado: Joi.boolean().default(true),
});

const agregarCumpleanoSchema = Joi.object({
  id: Joi.number().integer().positive().allow(null).optional(),
  nombre: Joi.string().max(255).required().messages({
    'string.empty': 'El nombre es requerido',
    'any.required': 'El nombre es requerido',
  }),
  cargo: Joi.string().max(100).allow('', null).optional(),
  dia: Joi.number().integer().min(1).max(31).required().messages({
    'number.min': 'El día debe ser entre 1 y 31',
    'number.max': 'El día debe ser entre 1 y 31',
    'any.required': 'El día es requerido',
  }),
  mes: Joi.number().integer().min(1).max(12).required().messages({
    'number.min': 'El mes debe ser entre 1 y 12',
    'number.max': 'El mes debe ser entre 1 y 12',
    'any.required': 'El mes es requerido',
  }),
  area_id: Joi.number().integer().positive().allow(null).optional(),
  estado: Joi.boolean().default(true),
});

const agregarAvisoSchema = Joi.object({
  id: Joi.number().integer().positive().allow(null).optional(),
  titulo: Joi.string().max(255).required().messages({
    'string.empty': 'El título es requerido',
    'any.required': 'El título es requerido',
  }),
  mensaje: Joi.string().required().messages({
    'string.empty': 'El mensaje es requerido',
    'any.required': 'El mensaje es requerido',
  }),
  prioridad: Joi.string().valid('normal', 'importante', 'muy_importante').default('normal'),
  modo_display: Joi.string().valid('permanente', 'periodico').default('periodico'),
  area_id: Joi.number().integer().positive().allow(null).optional(),
  fecha_inicio: Joi.string().allow('', null).optional(),
  fecha_fin: Joi.string().allow('', null).optional(),
  estado: Joi.boolean().default(true),
});

const contenidoTvHoySchema = Joi.object({
  area_id: Joi.number().integer().positive().required().messages({
    'number.base': 'El area_id debe ser un número',
    'any.required': 'El area_id es requerido',
  }),
});

const idParamSchema = Joi.object({
  id: Joi.number().integer().positive().required().messages({
    'number.base': 'El id debe ser un número',
    'any.required': 'El id es requerido',
  }),
});

const agregarPantallaTvSchema = Joi.object({
  id: Joi.number().integer().positive().allow(null).optional(),
  nombre: Joi.string().max(100).required().messages({
    'string.empty': 'El nombre es requerido',
    'any.required': 'El nombre es requerido',
  }),
  token: Joi.string().max(64).allow(null).optional(),
  area_id: Joi.number().integer().positive().allow(null).optional(),
  area_nombre: Joi.string().max(255).allow('', null).optional(),
  cod_hab_cama: Joi.string().max(255).allow('', null).optional(),
  estado: Joi.boolean().default(true),
});

module.exports = {
  agregarEfemerideSchema,
  agregarCumpleanoSchema,
  agregarAvisoSchema,
  contenidoTvHoySchema,
  idParamSchema,
  agregarPantallaTvSchema,
};
