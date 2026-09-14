const bcrypt = require('bcrypt');
const db = require('../../database/pool');
const { generarToken } = require('../../utils/jwt');
const logger = require('../../utils/logger');

const SALT_ROUNDS = 10;

async function registrar(data) {
  const { id = 0, nombre, usuario, clave, estado = true } = data;

  logger.debug(`Registrando usuario: ${usuario}`);

  const hashedPassword = await bcrypt.hash(clave, SALT_ROUNDS);
  const result = await db.registrarUsuario(id, nombre, usuario, hashedPassword, estado);

  return result[0].result;
}

async function eliminar(data) {
  const { id } = data;

  logger.debug(`Eliminando usuario: ${id}`);

  const result = await db.eliminarUsuario(id);
  return result[0].result;
}

async function asignar(data) {
  const { id = 0, usuario_id, area_id, area_nombre, rol, estado = true, permisos = {} } = data;

  let finalAreaId = area_id;

  // Si viene area_nombre, buscar o crear el área automáticamente
  if (area_nombre && !area_id) {
    try {
      const existing = await db.pool.query(
        'SELECT id FROM public.areas WHERE nombre = $1',
        [area_nombre]
      );

      if (existing.rows.length > 0) {
        finalAreaId = existing.rows[0].id;
      } else {
        // Obtener un cod_ses válido de la tabla hospitales
        const hospResult = await db.pool.query(
          'SELECT cod_ses FROM public.hospitales LIMIT 1'
        );
        const codSes = hospResult.rows.length > 0 ? hospResult.rows[0].cod_ses : 1;

        const insertResult = await db.pool.query(
          'INSERT INTO public.areas (cod_ses, nombre, estado) VALUES ($1, $2, true) RETURNING id',
          [codSes, area_nombre]
        );
        finalAreaId = insertResult.rows[0].id;
        logger.info(`Area creada: ${area_nombre} (id: ${finalAreaId})`);
      }
    } catch (err) {
      logger.error(`Error al buscar/crear area "${area_nombre}": ${err.message}`);
      return { estado: 'error', codigo: 500, mensaje: `Error al crear area: ${err.message}` };
    }
  }

  logger.debug(`Asignando usuario ${usuario_id} a area ${finalAreaId}`);

  const result = await db.asignarUsuario(id, usuario_id, finalAreaId, rol, estado, permisos);
  return result[0].result;
}

async function login(data) {
  const { usuario, clave } = data;

  logger.debug(`Intento de login: ${usuario}`);

  const item = await db.login(usuario);
  const result = item[0].result;

  // Usuario no encontrado
  if (result.estado === 'error') {
    logger.warn(`Login fallido - usuario no encontrado: ${usuario}`);
    return { estado: 'error', codigo: result.codigo, mensaje: 'Usuario o Clave Incorrectos' };
  }

  const mensaje = result.mensaje;

  // Usuario inactivo
  if (mensaje.estado === false) {
    logger.warn(`Login fallido - usuario inactivo: ${usuario}`);
    return { estado: 'error', codigo: 403, mensaje: 'Usuario Inactivo' };
  }

  // Verificar contraseña
  const passwordMatch = await bcrypt.compare(clave, mensaje.clave);

  if (!passwordMatch) {
    logger.warn(`Login fallido - clave incorrecta: ${usuario}`);
    return { estado: 'error', codigo: 401, mensaje: 'Usuario o Clave Incorrectos' };
  }

  // Generar token (SIN incluir la clave hasheada)
  const tokenPayload = {
    id: mensaje.id,
    nombre: mensaje.nombre,
    usuario: mensaje.usuario,
    area_id: mensaje.area_id,
    area_nombre: mensaje.area_nombre,
    rol: mensaje.rol,
    permisos: mensaje.permisos || {},
  };

  const token = generarToken(tokenPayload);

  logger.info(`Login exitoso: ${usuario}`);

  return {
    estado: 'success',
    codigo: 200,
    mensaje: {
      ...tokenPayload,
      token,
    },
  };
}

/**
 * Renovar token JWT (requiere token vigente)
 */
async function refreshToken(user) {
  const tokenPayload = {
    id: user.id,
    nombre: user.nombre,
    usuario: user.usuario,
    area_id: user.area_id,
    area_nombre: user.area_nombre,
    rol: user.rol,
    permisos: user.permisos || {},
  };

  const token = generarToken(tokenPayload);

  logger.info(`Token renovado para: ${user.usuario}`);

  return {
    estado: 'success',
    codigo: 200,
    mensaje: {
      ...tokenPayload,
      token,
    },
  };
}

async function listar() {
  logger.debug('Listando usuarios');
  const result = await db.listarUsuarios();
  return result[0].result;
}

async function crearArea(data) {
  const { nombre, codigo_essi } = data;

  logger.debug(`Creando/buscando area: ${nombre}`);

  // Buscar si ya existe un area con ese nombre
  const existing = await db.pool.query(
    'SELECT id FROM public.areas WHERE nombre = $1',
    [nombre]
  );

  if (existing.rows.length > 0) {
    return { estado: 'success', codigo: 200, mensaje: { id: existing.rows[0].id } };
  }

  // Crear nueva area (cod_ses=1 por defecto)
  const result = await db.agregarArea(0, 1, nombre, true);
  const res = result[0].result;

  if (res.estado === 'success' && res.id) {
    return { estado: 'success', codigo: 201, mensaje: { id: res.id } };
  }

  return res;
}

async function cambiarClave(data) {
  const { id, clave } = data;

  logger.debug(`Cambiando clave de usuario: ${id}`);

  const hashedPassword = await bcrypt.hash(clave, SALT_ROUNDS);
  const result = await db.cambiarClave(id, hashedPassword);
  return result[0].result;
}

async function cambiarMiClave(data, userId) {
  const { clave_actual, clave_nueva } = data;

  logger.debug(`Usuario ${userId} cambiando su propia clave`);

  // Obtener usuario actual para verificar clave
  const userResult = await db.pool.query(
    'SELECT clave FROM public.usuarios WHERE id = $1',
    [userId]
  );

  if (userResult.rows.length === 0) {
    return { estado: 'error', codigo: 404, mensaje: 'Usuario no encontrado' };
  }

  const passwordMatch = await bcrypt.compare(clave_actual, userResult.rows[0].clave);
  if (!passwordMatch) {
    return { estado: 'error', codigo: 401, mensaje: 'La clave actual es incorrecta' };
  }

  const hashedPassword = await bcrypt.hash(clave_nueva, SALT_ROUNDS);
  const result = await db.cambiarClave(userId, hashedPassword);
  return result[0].result;
}

async function listarServicios() {
  logger.debug('Listando servicios hospitalarios');
  const result = await db.listarServiciosHospitalarios();
  return result[0].result;
}

/**
 * Consultar sub-áreas (codHabCama) desde la API externa EsSi
 */
async function previewSubAreas(data) {
  const axios = require('axios');
  const appConfig = require('../../config');
  const apiUrl = appConfig.api.essi;

  if (!apiUrl) {
    return { estado: 'error', codigo: 500, mensaje: 'API EsSi no configurada' };
  }

  const { oriCenAsiCod, cenAsiCod, areHosCod, servHosCod, estEnfCod } = data;

  logger.debug(`Preview sub-areas EsSi: servHosCod=${servHosCod}, estEnfCod=${estEnfCod}`);

  try {
    const response = await axios.post(apiUrl, {
      oriCenAsiCod, cenAsiCod, areHosCod, servHosCod, estEnfCod
    }, { timeout: 15000 });

    const apiData = response.data;

    if (apiData.codExito !== 1 || !apiData.vDataItem?.[0]?.vDataPacCama) {
      return { estado: 'success', codigo: 200, mensaje: [] };
    }

    const pacientes = apiData.vDataItem[0].vDataPacCama;

    // Extraer codHabCama únicos con su descripción
    const subAreasMap = new Map();
    for (const p of pacientes) {
      if (p.codHabCama && !subAreasMap.has(p.codHabCama)) {
        subAreasMap.set(p.codHabCama, {
          codHabCama: p.codHabCama,
          desEstCama: p.desEstCama,
          desSerCama: p.desSerCama,
          totalCamas: 0
        });
      }
      if (p.codHabCama && subAreasMap.has(p.codHabCama)) {
        subAreasMap.get(p.codHabCama).totalCamas++;
      }
    }

    const subAreas = Array.from(subAreasMap.values());
    logger.info(`Preview sub-areas: ${subAreas.length} encontradas para estEnfCod=${estEnfCod}`);

    return { estado: 'success', codigo: 200, mensaje: subAreas };
  } catch (error) {
    logger.error(`Error preview sub-areas: ${error.message}`);
    return { estado: 'error', codigo: 500, mensaje: `Error al consultar API EsSi: ${error.message}` };
  }
}

async function listarAreas() {
  logger.debug('Listando areas activas');
  try {
    const result = await db.pool.query(
      'SELECT id, nombre FROM public.areas WHERE estado = true ORDER BY nombre'
    );
    return { estado: 'success', codigo: 200, mensaje: result.rows };
  } catch (error) {
    logger.error(`Error listando areas: ${error.message}`);
    return { estado: 'error', codigo: 500, mensaje: error.message };
  }
}

module.exports = {
  registrar,
  eliminar,
  asignar,
  login,
  refreshToken,
  listar,
  crearArea,
  cambiarClave,
  cambiarMiClave,
  listarServicios,
  previewSubAreas,
  listarAreas,
};
