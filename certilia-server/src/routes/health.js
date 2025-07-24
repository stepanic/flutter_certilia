import { Router } from 'express';
import sessionService from '../services/sessionService.js';

const router = Router();

/**
 * @route GET /health
 * @desc Health check endpoint
 * @returns {Object} Server health status
 */
router.get('/', (req, res) => {
  res.json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    environment: process.env.NODE_ENV,
  });
});

/**
 * @route GET /health/ready
 * @desc Readiness check endpoint
 * @returns {Object} Server readiness status
 */
router.get('/ready', async (req, res) => {
  try {
    // Check if all services are ready
    // In production, you might check database connections, etc.
    
    res.json({
      status: 'ready',
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    res.status(503).json({
      status: 'not ready',
      timestamp: new Date().toISOString(),
      error: error.message,
    });
  }
});

/**
 * @route GET /health/stats
 * @desc Get server statistics (protected endpoint)
 * @returns {Object} Server statistics
 */
router.get('/stats', (req, res) => {
  const stats = {
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    memory: process.memoryUsage(),
    sessions: sessionService.getStats(),
  };

  res.json(stats);
});

export default router;