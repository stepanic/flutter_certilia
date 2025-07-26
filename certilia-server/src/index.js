import express from 'express';
import helmet from 'helmet';
import cors from 'cors';
import rateLimit from 'express-rate-limit';
import path from 'path';
import { fileURLToPath } from 'url';
import { config } from './config/index.js';
import logger from './utils/logger.js';
import authRoutes from './routes/auth.js';
import healthRoutes from './routes/health.js';
import userRoutes from './routes/userRoutes.js';
import { errorHandler, notFoundHandler } from './middleware/errorHandler.js';

// Get __dirname equivalent in ES modules
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Create Express app
const app = express();

// Security middleware with updated CSP for callback page
app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      styleSrc: ["'self'", "'unsafe-inline'"],
      scriptSrc: ["'self'"],
      connectSrc: ["'self'", "*"],
    },
  },
}));

// CORS configuration
app.use(cors({
  origin: (origin, callback) => {
    // Allow requests with no origin (like mobile apps or Postman)
    if (!origin) return callback(null, true);
    
    // In development, allow all localhost origins
    if (config.isDevelopment && origin.includes('localhost')) {
      return callback(null, true);
    }
    
    if (config.cors.origins.includes(origin)) {
      callback(null, true);
    } else {
      callback(new Error('Not allowed by CORS'));
    }
  },
  credentials: config.cors.credentials,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization'],
}));

// Rate limiting
const limiter = rateLimit({
  windowMs: config.rateLimit.windowMs,
  max: config.rateLimit.max,
  message: 'Too many requests from this IP, please try again later.',
  standardHeaders: true,
  legacyHeaders: false,
});

app.use('/api', limiter);

// Body parsing middleware
app.use(express.json({ limit: '1mb' }));
app.use(express.urlencoded({ extended: true, limit: '1mb' }));

// Serve static files from public directory
app.use(express.static(path.join(__dirname, '../public')));

// Special handling for .well-known files (must be served with correct content-type)
app.get('/.well-known/apple-app-site-association', (req, res) => {
  res.type('application/json');
  res.sendFile(path.join(__dirname, '../public/.well-known/apple-app-site-association'));
});

app.get('/.well-known/assetlinks.json', (req, res) => {
  res.type('application/json');
  res.sendFile(path.join(__dirname, '../public/.well-known/assetlinks.json'));
});

// Request logging
app.use((req, res, next) => {
  logger.info('Incoming request', {
    method: req.method,
    url: req.url,
    ip: req.ip,
    userAgent: req.get('user-agent'),
  });
  next();
});

// Routes
app.use('/api/auth', authRoutes);
app.use('/api/health', healthRoutes);
app.use('/api/user', userRoutes);

// Root endpoint
app.get('/', (req, res) => {
  res.json({
    name: 'Certilia OAuth Server',
    version: '1.0.0',
    endpoints: {
      health: '/api/health',
      auth: {
        initialize: 'GET /api/auth/initialize',
        callback: 'GET /api/auth/callback',
        exchange: 'POST /api/auth/exchange',
        refresh: 'POST /api/auth/refresh',
        user: 'GET /api/auth/user',
        logout: 'POST /api/auth/logout',
      },
      user: {
        extendedInfo: 'GET /api/user/extended-info',
      },
    },
  });
});

// 404 handler
app.use(notFoundHandler);

// Error handling
app.use(errorHandler);

// Start server
const PORT = config.port;
const server = app.listen(PORT, () => {
  logger.info(`Server started on port ${PORT}`);
  logger.info(`Environment: ${config.env}`);
  logger.info(`CORS origins: ${config.cors.origins.join(', ')}`);
});

// Graceful shutdown
process.on('SIGTERM', () => {
  logger.info('SIGTERM signal received: closing HTTP server');
  server.close(() => {
    logger.info('HTTP server closed');
    process.exit(0);
  });
});

process.on('SIGINT', () => {
  logger.info('SIGINT signal received: closing HTTP server');
  server.close(() => {
    logger.info('HTTP server closed');
    process.exit(0);
  });
});

// Handle uncaught exceptions
process.on('uncaughtException', (error) => {
  logger.error('Uncaught Exception:', error);
  process.exit(1);
});

process.on('unhandledRejection', (reason, promise) => {
  logger.error('Unhandled Rejection at:', promise, 'reason:', reason);
  process.exit(1);
});

export default app;