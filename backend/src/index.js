require('dotenv').config();

const app = require('./app');
const logger = require('./utils/logger');
const db = require('./database/pool');
const mqttService = require('./services/mqtt.service');
const { iniciarCronSync } = require('./jobs/syncPacientes');
const manualesExpirados = require('./jobs/manualesExpirados');

const PORT = app.get('port');

async function startServer() {
  try {
    // Verificar conexión a base de datos
    await db.testConnection();
    logger.info('Conexión a PostgreSQL establecida');

    // Iniciar servidor HTTP
    const server = app.listen(PORT, () => {
      logger.info(`Servidor ejecutándose en puerto ${PORT}`);
      logger.info(`Entorno: ${process.env.NODE_ENV || 'development'}`);
    });

    // Conectar al broker MQTT
    mqttService.connect();

    // Iniciar cron de sincronización de pacientes (lee intervalo desde BD)
    await iniciarCronSync();

    // Iniciar cron secundario de manuales expirados (cada 1 min)
    manualesExpirados.iniciar();

    // Graceful shutdown
    const shutdown = async (signal) => {
      logger.info(`${signal} recibido. Cerrando servidor...`);

      server.close(async () => {
        logger.info('Servidor HTTP cerrado');
        mqttService.disconnect();
        await db.closePool();
        logger.info('Pool de conexiones cerrado');
        process.exit(0);
      });

      // Forzar cierre después de 10 segundos
      setTimeout(() => {
        logger.error('Cierre forzado por timeout');
        process.exit(1);
      }, 10000);
    };

    process.on('SIGTERM', () => shutdown('SIGTERM'));
    process.on('SIGINT', () => shutdown('SIGINT'));
  } catch (error) {
    logger.error('Error al iniciar el servidor', { error: error.message });
    process.exit(1);
  }
}

startServer();
