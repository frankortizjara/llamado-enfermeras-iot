const Joi = require('joi');

const loginSchema = Joi.object({
  usuario: Joi.string().required().messages({
    'string.empty': 'El usuario es requerido',
    'any.required': 'El usuario es requerido',
  }),
  clave: Joi.string().required().messages({
    'string.empty': 'La clave es requerida',
    'any.required': 'La clave es requerida',
  }),
});

const registrarSchema = Joi.object({
  id: Joi.number().integer().default(0),
  nombre: Joi.string().min(2).max(255).required().messages({
    'string.empty': 'El nombre es requerido',
    'string.min': 'El nombre debe tener al menos 2 caracteres',
    'string.max': 'El nombre no puede exceder 255 caracteres',
    'any.required': 'El nombre es requerido',
  }),
  usuario: Joi.string().min(3).max(255).required().messages({
    'string.empty': 'El usuario es requerido',
    'string.min': 'El usuario debe tener al menos 3 caracteres',
    'string.max': 'El usuario no puede exceder 255 caracteres',
    'any.required': 'El usuario es requerido',
  }),
  clave: Joi.string().min(6).max(255).required().messages({
    'string.empty': 'La clave es requerida',
    'string.min': 'La clave debe tener al menos 6 caracteres',
    'string.max': 'La clave no puede exceder 255 caracteres',
    'any.required': 'La clave es requerida',
  }),
  estado: Joi.boolean().default(true),
});

const eliminarSchema = Joi.object({
  id: Joi.number().integer().positive().required().messages({
    'number.base': 'El id debe ser un numero',
    'number.positive': 'El id debe ser positivo',
    'any.required': 'El id es requerido',
  }),
});

const asignarSchema = Joi.object({
  id: Joi.number().integer().default(0),
  usuario_id: Joi.number().integer().positive().required().messages({
    'number.base': 'El usuario_id debe ser un numero',
    'number.positive': 'El usuario_id debe ser positivo',
    'any.required': 'El usuario_id es requerido',
  }),
  area_id: Joi.number().integer().positive().optional().messages({
    'number.base': 'El area_id debe ser un numero',
    'number.positive': 'El area_id debe ser positivo',
  }),
  area_nombre: Joi.string().max(255).optional().messages({
    'string.max': 'El area_nombre no puede exceder 255 caracteres',
  }),
  rol: Joi.string().max(50).required().messages({
    'string.empty': 'El rol es requerido',
    'string.max': 'El rol no puede exceder 50 caracteres',
    'any.required': 'El rol es requerido',
  }),
  estado: Joi.boolean().default(true),
  permisos: Joi.object().default({}),
});

const cambiarClaveSchema = Joi.object({
  id: Joi.number().integer().positive().required().messages({
    'number.base': 'El id debe ser un numero',
    'number.positive': 'El id debe ser positivo',
    'any.required': 'El id es requerido',
  }),
  clave: Joi.string().min(6).max(255).required().messages({
    'string.empty': 'La clave es requerida',
    'string.min': 'La clave debe tener al menos 6 caracteres',
    'string.max': 'La clave no puede exceder 255 caracteres',
    'any.required': 'La clave es requerida',
  }),
});

const cambiarMiClaveSchema = Joi.object({
  clave_actual: Joi.string().required().messages({
    'string.empty': 'La clave actual es requerida',
    'any.required': 'La clave actual es requerida',
  }),
  clave_nueva: Joi.string().min(6).max(255).required().messages({
    'string.empty': 'La nueva clave es requerida',
    'string.min': 'La nueva clave debe tener al menos 6 caracteres',
    'string.max': 'La nueva clave no puede exceder 255 caracteres',
    'any.required': 'La nueva clave es requerida',
  }),
});

const previewSubAreasSchema = Joi.object({
  oriCenAsiCod: Joi.string().required(),
  cenAsiCod: Joi.string().required(),
  areHosCod: Joi.string().required(),
  servHosCod: Joi.string().required(),
  estEnfCod: Joi.string().required(),
});

module.exports = {
  loginSchema,
  registrarSchema,
  eliminarSchema,
  asignarSchema,
  cambiarClaveSchema,
  cambiarMiClaveSchema,
  previewSubAreasSchema,
};
