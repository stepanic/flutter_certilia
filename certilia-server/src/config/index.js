import dotenv from 'dotenv';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// Load environment variables
dotenv.config({ path: join(__dirname, '../../.env') });

export const config = {
  // Server Configuration
  env: process.env.NODE_ENV || 'development',
  port: parseInt(process.env.PORT, 10) || 3000,
  
  // Certilia OAuth Configuration
  certilia: {
    clientId: process.env.CERTILIA_CLIENT_ID,
    clientSecret: process.env.CERTILIA_CLIENT_SECRET,
    redirectUri: process.env.CERTILIA_REDIRECT_URI || 'http://localhost:3000/auth/callback',
    baseUrl: process.env.CERTILIA_BASE_URL || 'https://idp.test.certilia.com',
    authEndpoint: process.env.CERTILIA_AUTH_ENDPOINT || '/oauth2/authorize',
    tokenEndpoint: process.env.CERTILIA_TOKEN_ENDPOINT || '/oauth2/token',
    userInfoEndpoint: process.env.CERTILIA_USERINFO_ENDPOINT || '/oauth2/userinfo',
    discoveryEndpoint: process.env.CERTILIA_DISCOVERY_ENDPOINT || '/oauth2/oidcdiscovery/.well-known/openid-configuration',
    scopes: ['openid', 'profile', 'eid', 'email', 'offline_access'],
  },
  
  // Security Configuration
  jwt: {
    secret: process.env.JWT_SECRET || 'change-this-secret-in-production',
    expiry: process.env.JWT_EXPIRY || '1h',
    refreshExpiry: process.env.REFRESH_TOKEN_EXPIRY || '7d',
  },
  
  // Session Configuration
  session: {
    secret: process.env.SESSION_SECRET || 'change-this-session-secret',
  },
  
  // CORS Configuration
  cors: {
    origins: process.env.ALLOWED_ORIGINS 
      ? process.env.ALLOWED_ORIGINS.split(',').map(origin => origin.trim())
      : ['http://localhost:8080', 'http://localhost:3000'],
    credentials: true,
  },
  
  // Redis Configuration
  redis: {
    url: process.env.REDIS_URL || 'redis://localhost:6379',
    ttl: parseInt(process.env.REDIS_TTL, 10) || 3600,
  },
  
  // Logging Configuration
  logging: {
    level: process.env.LOG_LEVEL || 'info',
    file: process.env.LOG_FILE || 'logs/certilia-server.log',
  },
  
  // Rate Limiting
  rateLimit: {
    windowMs: parseInt(process.env.RATE_LIMIT_WINDOW_MS, 10) || 15 * 60 * 1000, // 15 minutes
    max: parseInt(process.env.RATE_LIMIT_MAX_REQUESTS, 10) || 100,
  },
  
  // Development specific
  isDevelopment: process.env.NODE_ENV === 'development',
  isProduction: process.env.NODE_ENV === 'production',
};

// Validate required configuration
const requiredConfig = [
  'certilia.clientId',
  'certilia.clientSecret',
  'jwt.secret',
];

requiredConfig.forEach(key => {
  const keys = key.split('.');
  let value = config;
  
  for (const k of keys) {
    value = value[k];
  }
  
  if (!value) {
    throw new Error(`Missing required configuration: ${key}`);
  }
});

export default config;