import tokenService from '../services/tokenService.js';
import { AuthenticationError } from '../utils/errors.js';

/**
 * Authentication middleware
 * Verifies JWT token from Authorization header
 */
export const authenticate = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;

    // Debug logging for authorization header issues
    if (process.env.NODE_ENV === 'production' && !authHeader) {
      console.log('[AUTH DEBUG] Headers received:', Object.keys(req.headers));
      console.log('[AUTH DEBUG] Authorization header:', authHeader);
      console.log('[AUTH DEBUG] All auth-like headers:', Object.entries(req.headers).filter(([k]) => k.toLowerCase().includes('auth')));
    }

    const token = tokenService.extractTokenFromHeader(authHeader);

    if (!token) {
      throw new AuthenticationError('No token provided');
    }

    const decoded = tokenService.verifyToken(token, 'access');

    // Attach user info to request
    // Now all user data is at root level, not in nested 'user' object
    const { certilia_tokens, type, ...userData } = decoded;
    req.user = userData;  // All user data except certilia_tokens and type
    req.userId = decoded.sub;
    req.tokenId = decoded.jti;

    // Attach certilia tokens if present
    if (certilia_tokens) {
      req.certilia_tokens = certilia_tokens;
    }

    next();
  } catch (error) {
    next(error);
  }
};

/**
 * Optional authentication middleware
 * Verifies token if present but doesn't require it
 */
export const optionalAuthenticate = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;
    const token = tokenService.extractTokenFromHeader(authHeader);

    if (token) {
      const decoded = tokenService.verifyToken(token, 'access');
      // Now all user data is at root level, not in nested 'user' object
      const { certilia_tokens, type, ...userData } = decoded;
      req.user = userData;  // All user data except certilia_tokens and type
      req.userId = decoded.sub;
      req.tokenId = decoded.jti;

      // Attach certilia tokens if present
      if (certilia_tokens) {
        req.certilia_tokens = certilia_tokens;
      }
    }

    next();
  } catch (error) {
    // Ignore authentication errors for optional auth
    next();
  }
};