const Joi = require('joi');

const actualizarConfiguracionSchema = Joi.object({
  valor: Joi.string().max(255).required().messages({
    'string.empty': 'El valor es requerido',
    'any.required': 'El valor es requerido',
  }),
});

module.exports = {
  actualizarConfiguracionSchema,
};
