/**
 * Script para limpiar la tabla esp32_dispositivos y empezar de cero.
 * Uso: node scripts/cleanup_dispositivos.js [--check | --clean]
 *   --check  Solo muestra los registros actuales (default)
 *   --clean  Elimina todos los registros
 */
require('dotenv').config();
const { Pool } = require('pg');

const pool = new Pool({
  user: process.env.PGUSER,
  host: process.env.PGHOST,
  database: process.env.PGDATABASE,
  password: process.env.PGPASSWORD,
  port: process.env.PGPORT,
});

async function main() {
  const action = process.argv[2] || '--check';

  try {
    if (action === '--check') {
      console.log('\n=== Estado actual de esp32_dispositivos ===\n');

      const count = await pool.query('SELECT COUNT(*) as total FROM esp32_dispositivos');
      console.log(`Total registros: ${count.rows[0].total}`);

      const online = await pool.query(`
        SELECT COUNT(*) as total FROM esp32_dispositivos
        WHERE ultimo_heartbeat IS NOT NULL
          AND ultimo_heartbeat > (CURRENT_TIMESTAMP - INTERVAL '10 minutes')
      `);
      console.log(`Online (heartbeat <10min): ${online.rows[0].total}`);

      const withHeartbeat = await pool.query(`
        SELECT COUNT(*) as total FROM esp32_dispositivos
        WHERE ultimo_heartbeat IS NOT NULL
      `);
      console.log(`Con heartbeat registrado: ${withHeartbeat.rows[0].total}`);

      const withRoom = await pool.query(`
        SELECT COUNT(*) as total FROM esp32_dispositivos
        WHERE habitacion_id IS NOT NULL
      `);
      console.log(`Asignados a habitación: ${withRoom.rows[0].total}`);

      console.log('\n--- Últimos 5 dispositivos con heartbeat ---');
      const recent = await pool.query(`
        SELECT id, numero_serial, tipo_dispositivo, habitacion_id, ip,
               ultimo_heartbeat, estado,
               CASE
                 WHEN ultimo_heartbeat IS NOT NULL
                   AND ultimo_heartbeat > (CURRENT_TIMESTAMP - INTERVAL '10 minutes')
                 THEN 'ONLINE'
                 ELSE 'OFFLINE'
               END AS status
        FROM esp32_dispositivos
        WHERE ultimo_heartbeat IS NOT NULL
        ORDER BY ultimo_heartbeat DESC
        LIMIT 5
      `);

      if (recent.rows.length === 0) {
        console.log('  (ninguno tiene heartbeat)');
      } else {
        recent.rows.forEach(r => {
          console.log(`  ID:${r.id} Serial:${r.numero_serial} Tipo:${r.tipo_dispositivo} Hab:${r.habitacion_id} IP:${r.ip} HB:${r.ultimo_heartbeat} => ${r.status}`);
        });
      }

      // Check for FK references
      const alertas = await pool.query(`
        SELECT COUNT(*) as total FROM alertas
        WHERE dispositivo_id IN (SELECT id FROM esp32_dispositivos)
      `);
      console.log(`\nAlertas referenciando dispositivos: ${alertas.rows[0].total}`);

      console.log('\n--- Tipos de dispositivos ---');
      const tipos = await pool.query(`
        SELECT tipo_dispositivo, COUNT(*) as total
        FROM esp32_dispositivos GROUP BY tipo_dispositivo
      `);
      tipos.rows.forEach(r => console.log(`  ${r.tipo_dispositivo || 'NULL'}: ${r.total}`));

    } else if (action === '--clean') {
      console.log('\n=== LIMPIANDO esp32_dispositivos ===\n');

      // First check alerts
      const alertas = await pool.query(`
        SELECT COUNT(*) as total FROM alertas
        WHERE dispositivo_id IN (SELECT id FROM esp32_dispositivos)
      `);
      console.log(`Alertas referenciando dispositivos: ${alertas.rows[0].total}`);

      // Use TRUNCATE CASCADE to handle FK
      await pool.query('TRUNCATE TABLE esp32_dispositivos CASCADE');
      console.log('Tabla esp32_dispositivos limpiada (CASCADE).');

      // Reset sequence
      await pool.query("SELECT setval('esp32_dispositivos_id_seq', 1, false)");
      console.log('Secuencia reiniciada a 1.');

      const verify = await pool.query('SELECT COUNT(*) as total FROM esp32_dispositivos');
      console.log(`Registros restantes: ${verify.rows[0].total}`);

      console.log('\nListo. Los ESP32 se registrarán automáticamente al enviar su primer heartbeat.');
    } else {
      console.log('Uso: node scripts/cleanup_dispositivos.js [--check | --clean]');
    }
  } catch (err) {
    console.error('Error:', err.message);
  } finally {
    await pool.end();
  }
}

main();
