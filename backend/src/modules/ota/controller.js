const fs = require('fs');
const path = require('path');
const logger = require('../../utils/logger');

const FIRMWARES_DIR = path.join(__dirname, '../../../firmwares');

/**
 * Compara dos versiones semver (ej: "2.0.0" > "1.0.0")
 * Retorna: 1 si a > b, -1 si a < b, 0 si iguales
 */
function compararVersiones(a, b) {
  const pa = a.split('.').map(Number);
  const pb = b.split('.').map(Number);
  for (let i = 0; i < 3; i++) {
    const va = pa[i] || 0;
    const vb = pb[i] || 0;
    if (va > vb) return 1;
    if (va < vb) return -1;
  }
  return 0;
}

/**
 * Obtiene la lista de firmwares disponibles ordenados por version desc
 */
function obtenerFirmwares() {
  if (!fs.existsSync(FIRMWARES_DIR)) {
    fs.mkdirSync(FIRMWARES_DIR, { recursive: true });
    return [];
  }

  const archivos = fs.readdirSync(FIRMWARES_DIR).filter((f) => f.endsWith('.bin'));

  const firmwares = archivos.map((archivo) => {
    const filePath = path.join(FIRMWARES_DIR, archivo);
    const stats = fs.statSync(filePath);

    // Extraer version del nombre: firmware_2.0.0.bin o firmware_v2.0.0.bin
    const match = archivo.match(/(\d+\.\d+\.\d+)/);
    const version = match ? match[1] : '0.0.0';

    // Leer metadata si existe
    const metaPath = filePath.replace('.bin', '.json');
    let meta = {};
    if (fs.existsSync(metaPath)) {
      try {
        meta = JSON.parse(fs.readFileSync(metaPath, 'utf8'));
      } catch (e) {
        // ignorar metadata corrupta
      }
    }

    return {
      archivo,
      version,
      tamano: stats.size,
      tamano_kb: Math.round(stats.size / 1024),
      fecha_subida: meta.fecha_subida || stats.mtime.toISOString(),
      descripcion: meta.descripcion || '',
    };
  });

  // Ordenar por version descendente
  firmwares.sort((a, b) => compararVersiones(b.version, a.version));
  return firmwares;
}

/**
 * POST /api/ota/check
 * El ESP32 consulta si hay nueva version. Sin autenticacion.
 */
async function checkUpdate(data) {
  const { numero_serial, firmware_version, tipo_dispositivo } = data;

  logger.info(`OTA Check - Serial: ${numero_serial}, Version: ${firmware_version}, Tipo: ${tipo_dispositivo}`);

  const firmwares = obtenerFirmwares();

  if (firmwares.length === 0) {
    return {
      update: false,
      message: 'No hay firmwares disponibles',
    };
  }

  const ultimo = firmwares[0];

  if (compararVersiones(ultimo.version, firmware_version) > 0) {
    logger.info(`OTA Update disponible para ${numero_serial}: ${firmware_version} -> ${ultimo.version}`);
    return {
      update: true,
      version: ultimo.version,
      archivo: ultimo.archivo,
      tamano: ultimo.tamano,
      url: `/api/ota/firmware/${ultimo.archivo}`,
      message: `Nueva version disponible: ${ultimo.version}`,
    };
  }

  return {
    update: false,
    version: firmware_version,
    message: 'Firmware actualizado',
  };
}

/**
 * GET /api/ota/firmware/:filename
 * Descarga del archivo .bin. Sin autenticacion (el ESP32 lo descarga).
 */
function getFirmwarePath(filename) {
  // Sanitizar filename para evitar path traversal
  const sanitized = path.basename(filename);
  const filePath = path.join(FIRMWARES_DIR, sanitized);

  if (!fs.existsSync(filePath)) {
    return null;
  }

  return filePath;
}

/**
 * POST /api/ota/upload
 * Subir firmware .bin. Requiere autenticacion.
 */
async function uploadFirmware(file, metadata) {
  const { version, descripcion } = metadata;

  if (!file) {
    return {
      estado: 'error',
      mensaje: 'No se recibio archivo .bin',
      codigo: 400,
    };
  }

  // Validar extension
  if (!file.originalname.endsWith('.bin')) {
    // Eliminar archivo subido
    fs.unlinkSync(file.path);
    return {
      estado: 'error',
      mensaje: 'Solo se aceptan archivos .bin',
      codigo: 400,
    };
  }

  // Nombre del archivo final: firmware_X.X.X.bin
  const nombreFinal = `firmware_${version}.bin`;
  const rutaFinal = path.join(FIRMWARES_DIR, nombreFinal);

  // Si ya existe esa version, sobreescribir
  if (fs.existsSync(rutaFinal)) {
    fs.unlinkSync(rutaFinal);
    logger.info(`OTA Upload - Sobreescribiendo version ${version}`);
  }

  // Mover archivo
  fs.renameSync(file.path, rutaFinal);

  // Guardar metadata
  const metaPath = rutaFinal.replace('.bin', '.json');
  const meta = {
    version,
    descripcion,
    fecha_subida: new Date().toISOString(),
    tamano: fs.statSync(rutaFinal).size,
    nombre_original: file.originalname,
  };
  fs.writeFileSync(metaPath, JSON.stringify(meta, null, 2));

  logger.info(`OTA Upload - Firmware ${version} subido (${Math.round(meta.tamano / 1024)} KB)`);

  return {
    estado: 'ok',
    mensaje: `Firmware ${version} subido exitosamente`,
    codigo: 201,
    data: {
      archivo: nombreFinal,
      version,
      tamano_kb: Math.round(meta.tamano / 1024),
    },
  };
}

/**
 * GET /api/ota/list
 * Listar firmwares disponibles. Requiere autenticacion.
 */
async function listarFirmwares() {
  const firmwares = obtenerFirmwares();

  return {
    estado: 'ok',
    mensaje: firmwares,
    codigo: 200,
  };
}

/**
 * DELETE /api/ota/firmware/:filename
 * Eliminar un firmware. Requiere autenticacion.
 */
async function eliminarFirmware(filename) {
  const sanitized = path.basename(filename);
  const filePath = path.join(FIRMWARES_DIR, sanitized);

  if (!fs.existsSync(filePath)) {
    return {
      estado: 'error',
      mensaje: 'Firmware no encontrado',
      codigo: 404,
    };
  }

  fs.unlinkSync(filePath);

  // Eliminar metadata si existe
  const metaPath = filePath.replace('.bin', '.json');
  if (fs.existsSync(metaPath)) {
    fs.unlinkSync(metaPath);
  }

  logger.info(`OTA Delete - Firmware eliminado: ${sanitized}`);

  return {
    estado: 'ok',
    mensaje: `Firmware ${sanitized} eliminado`,
    codigo: 200,
  };
}

module.exports = {
  checkUpdate,
  getFirmwarePath,
  uploadFirmware,
  listarFirmwares,
  eliminarFirmware,
};
