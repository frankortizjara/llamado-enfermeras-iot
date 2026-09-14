const response = require('../utils/response');
const logger = require('../utils/logger');

/**
 * Middleware factory para verificacion de roles
 * Requiere que el usuario tenga uno de los roles especificados
 * Debe usarse DESPUES del middleware auth
 * @param {...string} roles - Roles permitidos
 */
const requireRole = (...roles) => {
  return (req, res, next) => {
    // El rol 'admin' tiene acceso a todo
    if (req.user?.rol === 'admin') {
      return next();
    }
    if (!req.user?.rol || !roles.includes(req.user.rol)) {
      logger.warn(`Acceso denegado - Usuario: ${req.user?.usuario}, Rol: ${req.user?.rol}, Requerido: ${roles.join(', ')}`);
      return response.forbidden(res, 'No tiene permisos para esta accion');
    }
    next();
  };
};

/**
 * Middleware factory para verificacion de permisos
 * Permite acceso si el usuario tiene alguno de los permisos especificados en su JWT
 * Admin siempre tiene acceso
 * @param {...string} permisos - Nombres de permisos requeridos (cualquiera)
 */
const requirePermission = (...permisos) => {
  return (req, res, next) => {
    if (req.user?.rol === 'admin') {
      return next();
    }
    const userPermisos = req.user?.permisos || {};
    const tienePermiso = permisos.some(p => userPermisos[p] === true);
    if (!tienePermiso) {
      logger.warn(`Acceso denegado por permiso - Usuario: ${req.user?.usuario}, Permisos requeridos: ${permisos.join(', ')}`);
      return response.forbidden(res, 'No tiene permisos para esta accion');
    }
    next();
  };
};

module.exports = {
  requireRole,
  requirePermission,
};
