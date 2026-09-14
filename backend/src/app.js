const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');

const config = require('./config');
const logger = require('./utils/logger');
const { errorHandler, globalLimiter, authLimiter } = require('./middlewares');

const path = require('path');

// Rutas de módulos
const ambientes = require('./modules/ambientes');
const analytics = require('./modules/analytics');
const audioConfig = require('./modules/audio-config');
const auditoria = require('./modules/auditoria');
const configuracion = require('./modules/configuracion');
const contenidoTv = require('./modules/contenido-tv');
const dispositivos = require('./modules/dispositivos');
const informacion = require('./modules/informacion');
const ota = require('./modules/ota');
const tvPublica = require('./modules/tv-publica');
const usuarios = require('./modules/usuarios');

const app = express();

// Trust proxy (necesario cuando está detrás de Nginx/Docker)
app.set('trust proxy', 1);

// Seguridad - headers HTTP
app.use(helmet());

// CORS - abierto según configuración del usuario
app.use(cors());

// Rate limiting global
app.use(globalLimiter);

// Parsing de requests (saltar JSON parser en peticiones multipart/form-data)
app.use((req, res, next) => {
  if (req.is('multipart/form-data')) {
    return next();
  }
  express.json({ limit: '10mb' })(req, res, next);
});
app.use(express.urlencoded({ extended: true }));

// Logging HTTP
app.use(
  morgan('combined', {
    stream: { write: (message) => logger.http(message.trim()) },
  })
);

// Configuración del puerto
app.set('port', config.app.port);

// Health check
app.get('/health', (req, res) => {
  res.json({
    status: 'ok',
    timestamp: new Date().toISOString(),
    environment: config.app.env,
  });
});

// Archivos estáticos - sonidos de audio subidos
app.use('/uploads/audio', express.static(path.join(__dirname, '../uploads/audio')));

// Rutas de la API
app.use('/api/ambientes', ambientes);
app.use('/api/analytics', analytics);
app.use('/api/audio-config', audioConfig);
app.use('/api/auditoria', auditoria);
app.use('/api/configuracion', configuracion);
app.use('/api/contenido-tv', contenidoTv);
app.use('/api/dispositivos', dispositivos);
app.use('/api/informacion', informacion);
app.use('/api/ota', ota);
app.use('/api/tv-publica', tvPublica);
app.use('/api/usuarios', usuarios);

// 404 - Ruta no encontrada
app.use((req, res) => {
  res.status(404).json({
    error: true,
    status: 404,
    body: `Ruta no encontrada: ${req.method} ${req.originalUrl}`,
  });
});

// Error handler global (debe ser el último middleware)
app.use(errorHandler);

module.exports = app;
