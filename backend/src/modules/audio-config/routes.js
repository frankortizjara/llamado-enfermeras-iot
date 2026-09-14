const express = require('express');
const multer = require('multer');
const path = require('path');
const controller = require('./controller');
const response = require('../../utils/response');
const { auth, requireRole, asyncHandler } = require('../../middlewares');

const router = express.Router();

// Configuración de multer para subida de audio
const storage = multer.diskStorage({
  destination: path.join(__dirname, '../../../uploads/audio'),
  filename: (req, file, cb) => {
    // Sanitizar nombre: remover caracteres especiales, mantener extensión
    const ext = path.extname(file.originalname).toLowerCase();
    const name = path.basename(file.originalname, ext)
      .replace(/[^a-zA-Z0-9_-]/g, '_')
      .substring(0, 50);
    const uniqueName = `${name}_${Date.now()}${ext}`;
    cb(null, uniqueName);
  }
});

const upload = multer({
  storage,
  limits: { fileSize: 2 * 1024 * 1024 }, // 2MB máximo
  fileFilter: (req, file, cb) => {
    const allowed = ['.mp3', '.wav'];
    const ext = path.extname(file.originalname).toLowerCase();
    if (allowed.includes(ext)) {
      cb(null, true);
    } else {
      cb(new Error('Solo se permiten archivos .mp3 y .wav'));
    }
  }
});

/**
 * GET /api/audio-config/sonidos
 * Listar sonidos disponibles (preset + custom)
 */
router.get(
  '/sonidos',
  auth,
  asyncHandler(async (req, res) => {
    const sonidos = controller.listarSonidos();
    return response.success(res, sonidos);
  })
);

/**
 * POST /api/audio-config/upload
 * Subir un archivo de sonido personalizado
 */
router.post(
  '/upload',
  auth,
  requireRole('jefe_area'),
  (req, res, next) => {
    upload.single('audio')(req, res, (err) => {
      if (err instanceof multer.MulterError) {
        if (err.code === 'LIMIT_FILE_SIZE') {
          return response.badRequest(res, 'El archivo excede el límite de 2MB');
        }
        return response.badRequest(res, err.message);
      }
      if (err) {
        return response.badRequest(res, err.message);
      }
      next();
    });
  },
  asyncHandler(async (req, res) => {
    if (!req.file) {
      return response.badRequest(res, 'No se recibió ningún archivo');
    }

    return response.success(res, {
      filename: req.file.filename,
      originalname: req.file.originalname,
      size: req.file.size
    });
  })
);

/**
 * DELETE /api/audio-config/sonidos/:filename
 * Eliminar un sonido personalizado
 */
router.delete(
  '/sonidos/:filename',
  auth,
  requireRole('jefe_area'),
  asyncHandler(async (req, res) => {
    const { filename } = req.params;
    if (!filename) {
      return response.badRequest(res, 'Nombre de archivo requerido');
    }

    const result = controller.eliminarSonido(filename);

    if (result.error) {
      return response.badRequest(res, result.mensaje);
    }

    return response.success(res, result.mensaje);
  })
);

module.exports = router;
