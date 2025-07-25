import tokenService from '../services/tokenService.js';
import { AuthenticationError } from '../utils/errors.js';

/**
 * Authentication middleware
 * Verifies JWT token from Authorization header
 */
export const authenticate = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;
    const token = tokenService.extractTokenFromHeader(authHeader);

    if (!token) {
      throw new AuthenticationError('No token provided');
    }

    const decoded = tokenService.verifyToken(token, 'access');
    
    // Attach user info to request
    req.user = decoded.user;
    req.userId = decoded.sub;
    req.tokenId = decoded.jti;
    
    // Attach certilia tokens if present
    if (decoded.certilia_tokens) {
      req.certilia_tokens = decoded.certilia_tokens;
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
      req.user = decoded.user;
      req.userId = decoded.sub;
      req.tokenId = decoded.jti;
    }

    next();
  } catch (error) {
    // Ignore authentication errors for optional auth
    next();
  }
};