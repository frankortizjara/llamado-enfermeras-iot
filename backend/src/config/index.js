require('dotenv').config();

const requiredEnvVars = ['JWT_SECRET', 'PGDATABASE', 'PGUSER', 'PGPASSWORD'];

// Validar variables de entorno obligatorias
for (const envVar of requiredEnvVars) {
  if (!process.env[envVar]) {
    console.error(`ERROR: Variable de entorno ${envVar} es obligatoria`);
    process.exit(1);
  }
}

module.exports = {
  env: process.env.NODE_ENV || 'development',
  isProduction: process.env.NODE_ENV === 'production',

  app: {
    port: parseInt(process.env.PORT, 10) || 4000,
  },

  jwt: {
    secret: process.env.JWT_SECRET,
    expiresIn: process.env.JWT_EXPIRES_IN || '24h',
  },

  api: {
    essi: process.env.API_ESSI,
    essiQa: process.env.API_ESSI_QA,
    timeout: parseInt(process.env.API_TIMEOUT, 10) || 30000,
    syncIntervalMinutes: parseInt(process.env.SYNC_INTERVAL_MINUTES, 10) || 30,
  },

  postgresql: {
    user: process.env.PGUSER,
    host: process.env.PGHOST || 'localhost',
    database: process.env.PGDATABASE,
    password: process.env.PGPASSWORD,
    port: parseInt(process.env.PGPORT, 10) || 5432,
    max: parseInt(process.env.PG_POOL_MAX, 10) || 20,
    idleTimeoutMillis: parseInt(process.env.PG_IDLE_TIMEOUT, 10) || 30000,
    connectionTimeoutMillis: parseInt(process.env.PG_CONN_TIMEOUT, 10) || 5000,
  },

  rateLimit: {
    windowMs: parseInt(process.env.RATE_LIMIT_WINDOW_MS, 10) || 15 * 60 * 1000, // 15 minutos
    max: parseInt(process.env.RATE_LIMIT_MAX, 10) || 100,
  },

  mqtt: {
    host: process.env.MQTT_HOST || 'localhost',
    port: parseInt(process.env.MQTT_PORT, 10) || 1883,
    user: process.env.MQTT_USER || 'esp32',
    password: process.env.MQTT_PASSWORD || 'CAMBIA_ESTA_PASSWORD',
  },
};
