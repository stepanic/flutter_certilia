import { Router } from 'express';

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

export default router;