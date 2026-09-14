const Joi = require('joi');

const consultarHabitacionesSchema = Joi.object({
  id: Joi.number().integer().positive().required().messages({
    'number.base': 'El id debe ser un numero',
    'number.positive': 'El id debe ser positivo',
    'any.required': 'El id es requerido',
  }),
});

const consultarHabitacionesEsSiSchema = Joi.object({
  codHabCama: Joi.string().max(255).required().messages({
    'string.empty': 'El codHabCama es requerido',
    'string.max': 'El codHabCama no puede exceder 255 caracteres',
    'any.required': 'El codHabCama es requerido',
  }),
});

const consultarAlertasSchema = Joi.object({
  area_id: Joi.number().integer().positive().required().messages({
    'number.base': 'El area_id debe ser un numero',
    'number.positive': 'El area_id debe ser positivo',
    'any.required': 'El area_id es requerido',
  }),
});

const editarNotaSchema = Joi.object({
  id: Joi.number().integer().positive().required().messages({
    'number.base': 'El id debe ser un numero',
    'number.positive': 'El id debe ser positivo',
    'any.required': 'El id es requerido',
  }),
  nota: Joi.string().max(50).allow('').required().messages({
    'string.max': 'La nota no puede exceder 50 caracteres',
    'any.required': 'La nota es requerida',
  }),
  fecha_nota: Joi.string().max(255).allow('').optional(),
});

const cargarDataEsSiSchema = Joi.object({
  apeNomPac: Joi.string().max(255).required(),
  codHabCama: Joi.string().max(255).required(),
  codHab: Joi.string().max(255).required(),
  codCama: Joi.string().max(255).required(),
  desEstCama: Joi.string().max(255).required(),
  desSerCama: Joi.string().max(255).required(),
  diashospi: Joi.string().max(255).required(),
  fechaIngreso: Joi.string().max(255).required(),
  nroDocIdePac: Joi.string().max(255).required(),
  nroHisCliCas: Joi.string().max(255).required(),
  tipoDocIdePac: Joi.string().max(255).required(),
});

const reconocerAlertaSchema = Joi.object({
  habitacion_id: Joi.number().integer().positive().required().messages({
    'number.base': 'El habitacion_id debe ser un numero',
    'number.positive': 'El habitacion_id debe ser positivo',
    'any.required': 'El habitacion_id es requerido',
  }),
});

const cambiarCamaPacienteSchema = Joi.object({
  id_origen: Joi.number().integer().positive().required().messages({
    'any.required': 'id_origen es requerido',
  }),
  id_destino: Joi.number().integer().positive().required().messages({
    'any.required': 'id_destino es requerido',
  }),
  motivo: Joi.string().max(500).allow('', null).optional(),
});

const cancelarCambioManualSchema = Joi.object({
  id_cama: Joi.number().integer().positive().required().messages({
    'any.required': 'id_cama es requerido',
  }),
});

const ingresarPacienteManualSchema = Joi.object({
  id_cama: Joi.number().integer().positive().required().messages({
    'any.required': 'id_cama es requerido',
  }),
  nro_doc_ide_pac: Joi.string().trim().min(1).max(20).required().messages({
    'any.required': 'El DNI es obligatorio',
    'string.empty': 'El DNI es obligatorio',
  }),
  tipo_doc_ide_pac: Joi.string().max(10).allow('', null).optional(),
  ape_nom_pac: Joi.string().trim().min(1).max(255).required().messages({
    'any.required': 'El nombre del paciente es obligatorio',
    'string.empty': 'El nombre del paciente es obligatorio',
  }),
  nro_his_cli_cas: Joi.string().max(50).allow('', null).optional(),
  des_ser_cama: Joi.string().max(255).allow('', null).optional(),
  fecha_salida_obligatoria: Joi.string().isoDate().required().messages({
    'any.required': 'La fecha de salida obligatoria es requerida',
    'string.isoDate': 'La fecha de salida obligatoria debe estar en formato ISO',
  }),
  pertenece_al_area: Joi.boolean().required().messages({
    'any.required': 'Indique si el paciente pertenece al area o viene de otra',
  }),
  motivo: Joi.string().max(500).allow('', null).optional(),
});

module.exports = {
  consultarHabitacionesSchema,
  consultarHabitacionesEsSiSchema,
  consultarAlertasSchema,
  editarNotaSchema,
  cargarDataEsSiSchema,
  reconocerAlertaSchema,
  cambiarCamaPacienteSchema,
  cancelarCambioManualSchema,
  ingresarPacienteManualSchema,
};
