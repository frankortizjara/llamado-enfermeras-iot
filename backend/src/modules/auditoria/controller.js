const db = require('../../database/pool');
const logger = require('../../utils/logger');

function normalizarFiltros(query) {
  const norm = (v) => (v === '' || v === undefined ? null : v);
  return {
    desde: norm(query.desde),
    hasta: norm(query.hasta),
    usuario_id: norm(query.usuario_id) ? parseInt(query.usuario_id, 10) : null,
    accion: norm(query.accion),
    area_id: norm(query.area_id) ? parseInt(query.area_id, 10) : null,
    limit: query.limit ? parseInt(query.limit, 10) : 50,
    offset: query.offset ? parseInt(query.offset, 10) : 0,
  };
}

async function listar(query) {
  const filtros = normalizarFiltros(query);
  logger.debug(`Listando auditoria: ${JSON.stringify(filtros)}`);
  const result = await db.listarAuditoria(filtros);
  return result[0].result;
}

/**
 * Devuelve los registros como CSV. No usa paginacion -- aplica el limite
 * de exportacion en el SP (max 10000 registros por llamada).
 */
async function exportarCsv(query) {
  const filtros = normalizarFiltros(query);
  // Limite mas alto para exportacion
  filtros.limit = Math.min(filtros.limit || 10000, 10000);
  filtros.offset = 0;

  logger.info(`Exportando auditoria a CSV: ${JSON.stringify(filtros)}`);
  const result = await db.listarAuditoria(filtros);
  const sp = result[0].result;

  if (sp.estado === 'error') {
    return { ok: false, error: sp };
  }

  const registros = sp.mensaje?.registros || [];
  const headers = [
    'fecha_evento', 'accion', 'usuario_login', 'usuario_nombre',
    'codhabcama', 'codhab', 'codcama', 'paciente', 'nrodocidepac', 'detalle'
  ];

  // Escapar valores para CSV (RFC 4180): envolver en comillas si contiene , " o salto de linea
  const escapar = (val) => {
    if (val === null || val === undefined) return '';
    const s = String(val);
    if (/[",\r\n]/.test(s)) {
      return '"' + s.replace(/"/g, '""') + '"';
    }
    return s;
  };

  const lineas = [headers.join(',')];
  for (const r of registros) {
    lineas.push(headers.map(h => escapar(r[h])).join(','));
  }
  // Anteponer BOM UTF-8 para que Excel detecte la codificacion
  const csv = '﻿' + lineas.join('\r\n');

  return { ok: true, csv, total: registros.length };
}

module.exports = {
  listar,
  exportarCsv,
};
