import { Router } from 'express';
import * as authController from '../controllers/authController.js';
import { authenticate } from '../middleware/auth.js';
import { validate, schemas } from '../middleware/validation.js';

const router = Router();

/**
 * @route GET /auth/initialize
 * @desc Initialize OAuth flow and get authorization URL
 * @query {string} redirect_uri - OAuth redirect URI
 * @query {string} state - Optional client state
 * @returns {Object} Authorization URL and session info
 */
router.get(
  '/initialize',
  validate(schemas.authorizationRequest, 'query'),
  authController.initializeAuth
);

/**
 * @route GET /auth/callback
 * @desc OAuth callback endpoint (called by Certilia)
 * @query {string} code - Authorization code
 * @query {string} state - State parameter
 * @returns {HTML} Success page with embedded auth data
 */
router.get('/callback', authController.handleCallback);

/**
 * @route POST /auth/exchange
 * @desc Exchange authorization code for tokens
 * @body {string} code - Authorization code
 * @body {string} state - State parameter
 * @body {string} session_id - Session ID from initialize
 * @returns {Object} Access token, refresh token, and user info
 */
router.post(
  '/exchange',
  validate(schemas.authCallback),
  authController.exchangeCode
);

/**
 * @route POST /auth/refresh
 * @desc Refresh access token
 * @body {string} refresh_token - Refresh token
 * @returns {Object} New access and refresh tokens
 */
router.post(
  '/refresh',
  validate(schemas.refreshToken),
  authController.refreshToken
);


/**
 * @route POST /auth/polling/start
 * @desc Start polling session for cross-origin auth
 * @body {string} state - OAuth state
 * @body {string} session_id - Session ID
 * @returns {Object} Polling session info
 */
router.post('/polling/start', authController.startPolling);

/**
 * @route GET /auth/polling/:polling_id/status
 * @desc Check polling session status
 * @param {string} polling_id - Polling session ID
 * @returns {Object} Session status and result
 */
router.get('/polling/:polling_id/status', authController.checkPollingStatus);

export default router;