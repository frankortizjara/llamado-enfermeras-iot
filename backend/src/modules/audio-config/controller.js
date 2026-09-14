const fs = require('fs');
const path = require('path');

const UPLOADS_DIR = path.join(__dirname, '../../../uploads/audio');
const PRESET_SOUNDS = ['Beep01.mp3', 'Beep02.mp3'];

/**
 * Listar sonidos disponibles (preset + custom)
 */
function listarSonidos() {
  const custom = [];

  if (fs.existsSync(UPLOADS_DIR)) {
    const files = fs.readdirSync(UPLOADS_DIR);
    files.forEach(file => {
      const ext = path.extname(file).toLowerCase();
      if (ext === '.mp3' || ext === '.wav') {
        custom.push(file);
      }
    });
  }

  return {
    preset: PRESET_SOUNDS,
    custom: custom.sort()
  };
}

/**
 * Eliminar un sonido custom
 */
function eliminarSonido(filename) {
  // No permitir eliminar presets
  if (PRESET_SOUNDS.includes(filename)) {
    return { error: true, mensaje: 'No se pueden eliminar sonidos predeterminados' };
  }

  // Validar que no haya path traversal
  const safeName = path.basename(filename);
  const filePath = path.join(UPLOADS_DIR, safeName);

  if (!fs.existsSync(filePath)) {
    return { error: true, mensaje: 'Archivo no encontrado' };
  }

  fs.unlinkSync(filePath);
  return { error: false, mensaje: 'Sonido eliminado correctamente' };
}

module.exports = {
  listarSonidos,
  eliminarSonido,
};
