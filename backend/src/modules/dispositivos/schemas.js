const Joi = require('joi');

const agregarESP32Schema = Joi.object({
  numero_serial: Joi.string().max(12).required().messages({
    'string.empty': 'El numero_serial es requerido',
    'string.max': 'El numero_serial no puede exceder 12 caracteres',
    'any.required': 'El numero_serial es requerido',
  }),
  direccion_mac: Joi.string()
    .pattern(/^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$/)
    .required()
    .messages({
      'string.empty': 'La direccion_mac es requerida',
      'string.pattern.base': 'La direccion_mac debe tener formato XX:XX:XX:XX:XX:XX',
      'any.required': 'La direccion_mac es requerida',
    }),
  ip: Joi.string()
    .ip({ version: ['ipv4'] })
    .allow('')
    .optional()
    .messages({
      'string.ip': 'La IP debe ser una direccion IPv4 valida',
    }),
  estado: Joi.boolean().default(true),
});

const agregarRegistroSchema = Joi.object({
  numero_serial: Joi.string().max(12).required().messages({
    'string.empty': 'El numero_serial es requerido',
    'string.max': 'El numero_serial no puede exceder 12 caracteres',
    'any.required': 'El numero_serial es requerido',
  }),
  area_id: Joi.number().integer().positive().required().messages({
    'number.base': 'El area_id debe ser un numero',
    'number.positive': 'El area_id debe ser positivo',
    'any.required': 'El area_id es requerido',
  }),
  habitacion_id: Joi.number().integer().positive().required().messages({
    'number.base': 'El habitacion_id debe ser un numero',
    'number.positive': 'El habitacion_id debe ser positivo',
    'any.required': 'El habitacion_id es requerido',
  }),
  codigo_cama: Joi.string().max(50).required().messages({
    'string.empty': 'El codigo_cama es requerido',
    'string.max': 'El codigo_cama no puede exceder 50 caracteres',
    'any.required': 'El codigo_cama es requerido',
  }),
  tipo_alerta: Joi.number().integer().valid(1, 2, 3).required().messages({
    'number.base': 'El tipo_alerta debe ser un numero',
    'any.only': 'El tipo_alerta debe ser 1 (urgente), 2 (critica) o 3 (cancelada)',
    'any.required': 'El tipo_alerta es requerido',
  }),
});

const heartbeatSchema = Joi.object({
  numero_serial: Joi.string().max(12).required().messages({
    'string.empty': 'El numero_serial es requerido',
    'any.required': 'El numero_serial es requerido',
  }),
  direccion_mac: Joi.string()
    .pattern(/^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$/)
    .required()
    .messages({
      'string.pattern.base': 'La direccion_mac debe tener formato XX:XX:XX:XX:XX:XX',
      'any.required': 'La direccion_mac es requerida',
    }),
  ip: Joi.string().ip({ version: ['ipv4'] }).allow('').optional(),
  tipo_dispositivo: Joi.string().valid('luces', 'cuarto', 'bano', 'desconocido').default('desconocido'),
  habitacion_id: Joi.number().integer().positive().allow(null).default(null),
  relay_estado: Joi.boolean().default(false),
  uptime: Joi.number().integer().min(0).default(0),
  rssi: Joi.number().integer().max(0).default(0),
  firmware_version: Joi.string().max(20).allow('').optional(),
});

const estadisticasQuerySchema = Joi.object({
  fecha_inicio: Joi.string().isoDate().required().messages({
    'string.isoDate': 'fecha_inicio debe ser formato ISO (YYYY-MM-DD)',
    'any.required': 'fecha_inicio es requerida',
  }),
  fecha_fin: Joi.string().isoDate().required().messages({
    'string.isoDate': 'fecha_fin debe ser formato ISO (YYYY-MM-DD)',
    'any.required': 'fecha_fin es requerida',
  }),
});

const eventosQuerySchema = Joi.object({
  fecha_inicio: Joi.string().isoDate().required().messages({
    'string.isoDate': 'fecha_inicio debe ser formato ISO (YYYY-MM-DD)',
    'any.required': 'fecha_inicio es requerida',
  }),
  fecha_fin: Joi.string().isoDate().required().messages({
    'string.isoDate': 'fecha_fin debe ser formato ISO (YYYY-MM-DD)',
    'any.required': 'fecha_fin es requerida',
  }),
});

const controlRfSchema = Joi.object({
  id: Joi.number().integer().min(0).default(0),
  habitacion_id: Joi.number().integer().positive().required().messages({
    'number.base': 'El habitacion_id debe ser un numero',
    'number.positive': 'El habitacion_id debe ser positivo',
    'any.required': 'El habitacion_id es requerido',
  }),
  cama: Joi.string().max(10).required().messages({
    'string.empty': 'La cama es requerida',
    'any.required': 'La cama es requerida',
  }),
  dip_config: Joi.array().items(Joi.boolean()).length(8).required().messages({
    'array.length': 'dip_config debe tener exactamente 8 posiciones',
    'any.required': 'dip_config es requerido',
  }),
  descripcion: Joi.string().max(255).allow('').default(''),
  estado: Joi.boolean().default(true),
});

module.exports = {
  agregarESP32Schema,
  agregarRegistroSchema,
  heartbeatSchema,
  estadisticasQuerySchema,
  eventosQuerySchema,
  controlRfSchema,
};
