import { Router } from 'express';
import { authenticate } from '../middleware/auth.js';
import logger from '../utils/logger.js';

const router = Router();

/**
 * Debug routes - only available in development/testing
 * These should be disabled in production for security
 */

// Echo headers back to client
router.post('/echo-headers', (req, res) => {
  if (process.env.NODE_ENV === 'production' && !process.env.ENABLE_DEBUG_ENDPOINTS) {
    return res.status(404).json({ error: 'Not found' });
  }

  res.json({
    headers: req.headers,
    method: req.method,
    url: req.url,
    body: req.body,
    query: req.query,
    ip: req.ip,
    timestamp: new Date().toISOString(),
    environment: process.env.NODE_ENV,
    // Show specifically what auth middleware would see
    authHeader: req.headers.authorization || req.headers.Authorization || 'NOT_PRESENT',
    allAuthHeaders: Object.entries(req.headers)
      .filter(([key]) => key.toLowerCase().includes('auth'))
      .reduce((acc, [key, value]) => ({ ...acc, [key]: value }), {})
  });
});

// Test auth header parsing
router.get('/test-auth', (req, res) => {
  if (process.env.NODE_ENV === 'production' && !process.env.ENABLE_DEBUG_ENDPOINTS) {
    return res.status(404).json({ error: 'Not found' });
  }

  const authHeader = req.headers.authorization;
  const bearerMatch = authHeader?.match(/^Bearer\s+(.+)$/i);

  res.json({
    rawAuthHeader: authHeader,
    hasBearerPrefix: !!bearerMatch,
    extractedToken: bearerMatch?.[1] || null,
    headerKeys: Object.keys(req.headers),
    allHeaders: req.headers
  });
});

// Debug endpoint to show all available JWT data
router.get('/jwt-data', authenticate, (req, res) => {
  if (process.env.NODE_ENV === 'production' && !process.env.ENABLE_DEBUG_ENDPOINTS) {
    return res.status(404).json({ error: 'Not found' });
  }

  logger.info('Debug: JWT data requested');

  const response = {
    message: 'All available JWT data',
    userData: req.user,
    certiliaTokens: {
      hasAccessToken: !!req.certilia_tokens?.access_token,
      hasRefreshToken: !!req.certilia_tokens?.refresh_token,
      hasIdToken: !!req.certilia_tokens?.id_token,
      expiresIn: req.certilia_tokens?.expires_in,
      tokenType: req.certilia_tokens?.token_type
    },
    availableFields: req.user ? Object.keys(req.user) : [],
    environment: {
      skipUserInfo: process.env.SKIP_USERINFO_ENDPOINT === 'true',
      nodeEnv: process.env.NODE_ENV,
      certiliaBaseUrl: process.env.CERTILIA_BASE_URL
    }
  };

  res.json(response);
});

export default router;