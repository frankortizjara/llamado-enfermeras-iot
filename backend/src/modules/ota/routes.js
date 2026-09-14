const express = require('express');
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const controller = require('./controller');
const schemas = require('./schemas');
const response = require('../../utils/response');
const logger = require('../../utils/logger');
const { auth, validateBody, asyncHandler } = require('../../middlewares');

const router = express.Router();

// Asegurar que el directorio firmwares existe
const FIRMWARES_DIR = path.join(__dirname, '../../../firmwares');
if (!fs.existsSync(FIRMWARES_DIR)) {
  fs.mkdirSync(FIRMWARES_DIR, { recursive: true });
  logger.info('OTA: Directorio firmwares creado');
}

// Configurar multer para guardar temporalmente los .bin
const storage = multer.diskStorage({
  destination: function (req, file, cb) {
    cb(null, FIRMWARES_DIR);
  },
  filename: function (req, file, cb) {
    // Nombre temporal, se renombra en el controller
    cb(null, 'temp_' + Date.now() + '.bin');
  },
});

const upload = multer({
  storage,
  limits: { fileSize: 2 * 1024 * 1024 }, // Max 2MB
  fileFilter: function (req, file, cb) {
    if (file.originalname.endsWith('.bin')) {
      cb(null, true);
    } else {
      cb(new Error('Solo se aceptan archivos .bin'));
    }
  },
});

/**
 * POST /api/ota/check
 * El ESP32 verifica si hay actualizacion disponible (SIN autenticacion)
 */
router.post(
  '/check',
  validateBody(schemas.checkSchema),
  asyncHandler(async (req, res) => {
    const result = await controller.checkUpdate(req.body);
    return response.success(res, result);
  })
);

/**
 * GET /api/ota/firmware/:filename
 * Descarga del archivo .bin (SIN autenticacion - lo descarga el ESP32)
 */
router.get(
  '/firmware/:filename',
  asyncHandler(async (req, res) => {
    const filePath = controller.getFirmwarePath(req.params.filename);

    if (!filePath) {
      return response.notFound(res, 'Firmware no encontrado');
    }

    res.download(filePath);
  })
);

/**
 * POST /api/ota/upload
 * Subir un nuevo firmware .bin (requiere autenticacion)
 * Nota: auth va primero, luego multer procesa el file
 */
router.post(
  '/upload',
  auth,
  function (req, res, next) {
    upload.single('firmware')(req, res, function (err) {
      if (err) {
        logger.error(`OTA Upload multer error: ${err.message}`);
        if (err.code === 'LIMIT_FILE_SIZE') {
          return response.badRequest(res, 'El archivo excede el limite de 2MB');
        }
        return response.badRequest(res, err.message);
      }
      next();
    });
  },
  asyncHandler(async (req, res) => {
    const { version, descripcion } = req.body;

    // Validar metadata
    const { error: validationError } = schemas.uploadSchema.validate({ version, descripcion });
    if (validationError) {
      // Limpiar archivo temporal si existe
      if (req.file && req.file.path) {
        fs.unlink(req.file.path, () => {});
      }
      return response.badRequest(res, validationError.details[0].message);
    }

    const result = await controller.uploadFirmware(req.file, { version, descripcion });

    if (result.estado === 'error') {
      return response.error(res, result.mensaje, result.codigo);
    }

    return response.created(res, {
      mensaje: result.mensaje,
      data: result.data,
    });
  })
);

/**
 * GET /api/ota/list
 * Listar firmwares disponibles (requiere autenticacion)
 */
router.get(
  '/list',
  auth,
  asyncHandler(async (req, res) => {
    const result = await controller.listarFirmwares();
    return response.success(res, result.mensaje);
  })
);

/**
 * DELETE /api/ota/firmware/:filename
 * Eliminar un firmware (requiere autenticacion)
 */
router.delete(
  '/firmware/:filename',
  auth,
  asyncHandler(async (req, res) => {
    const result = await controller.eliminarFirmware(req.params.filename);

    if (result.estado === 'error') {
      return response.error(res, result.mensaje, result.codigo);
    }

    return response.success(res, result.mensaje);
  })
);

module.exports = router;
