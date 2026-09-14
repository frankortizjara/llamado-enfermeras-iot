const Joi = require('joi');

// Validacion de query params para listar auditoria.
// Convierte strings vacios a null para que pasen al SP.
const listarAuditoriaQuerySchema = Joi.object({
  desde: Joi.string().isoDate().allow('', null).optional(),
  hasta: Joi.string().isoDate().allow('', null).optional(),
  usuario_id: Joi.number().integer().positive().allow(null).optional(),
  accion: Joi.string().max(40).allow('', null).optional(),
  area_id: Joi.number().integer().positive().allow(null).optional(),
  limit: Joi.number().integer().min(1).max(500).default(50),
  offset: Joi.number().integer().min(0).default(0),
});

module.exports = {
  listarAuditoriaQuerySchema,
};
