import jwt from 'jsonwebtoken';
import { v4 as uuidv4 } from 'uuid';
import { config } from '../config/index.js';
import logger from '../utils/logger.js';
import { AuthenticationError } from '../utils/errors.js';

class TokenService {
  /**
   * Generate JWT access token
   * @param {Object} payload - Token payload
   * @param {string} payload.sub - Subject (user ID)
   * @param {Object} payload.user - User information
   * @returns {string} JWT token
   */
  generateAccessToken(payload) {
    const tokenPayload = {
      ...payload,
      iat: Math.floor(Date.now() / 1000),
      jti: uuidv4(),
      type: 'access',
    };

    return jwt.sign(tokenPayload, config.jwt.secret, {
      expiresIn: config.jwt.expiry,
      algorithm: 'HS256',
    });
  }

  /**
   * Generate JWT refresh token
   * @param {Object} payload - Token payload
   * @param {string} payload.sub - Subject (user ID)
   * @returns {string} JWT refresh token
   */
  generateRefreshToken(payload) {
    const tokenPayload = {
      sub: payload.sub,
      iat: Math.floor(Date.now() / 1000),
      jti: uuidv4(),
      type: 'refresh',
    };

    return jwt.sign(tokenPayload, config.jwt.secret, {
      expiresIn: config.jwt.refreshExpiry,
      algorithm: 'HS256',
    });
  }

  /**
   * Generate both access and refresh tokens
   * @param {Object} user - User object
   * @returns {Object} Tokens object
   */
  generateTokenPair(user) {
    const payload = {
      sub: user.sub,
      user: {
        sub: user.sub,
        firstName: user.firstName || user.given_name,
        lastName: user.lastName || user.family_name,
        oib: user.oib,
        email: user.email,
      },
    };

    const accessToken = this.generateAccessToken(payload);
    const refreshToken = this.generateRefreshToken(payload);

    // Decode to get expiration times
    const accessTokenDecoded = jwt.decode(accessToken);
    const refreshTokenDecoded = jwt.decode(refreshToken);

    return {
      accessToken,
      refreshToken,
      tokenType: 'Bearer',
      expiresIn: accessTokenDecoded.exp - accessTokenDecoded.iat,
      refreshExpiresIn: refreshTokenDecoded.exp - refreshTokenDecoded.iat,
    };
  }

  /**
   * Verify JWT token
   * @param {string} token - JWT token
   * @param {string} expectedType - Expected token type
   * @returns {Object} Decoded token payload
   */
  verifyToken(token, expectedType = null) {
    try {
      const decoded = jwt.verify(token, config.jwt.secret, {
        algorithms: ['HS256'],
      });

      if (expectedType && decoded.type !== expectedType) {
        throw new AuthenticationError('Invalid token type');
      }

      return decoded;
    } catch (error) {
      if (error.name === 'TokenExpiredError') {
        throw new AuthenticationError('Token has expired');
      } else if (error.name === 'JsonWebTokenError') {
        throw new AuthenticationError('Invalid token');
      }
      throw error;
    }
  }

  /**
   * Decode token without verification (for debugging)
   * @param {string} token - JWT token
   * @returns {Object} Decoded token
   */
  decodeToken(token) {
    return jwt.decode(token);
  }

  /**
   * Extract token from Authorization header
   * @param {string} authHeader - Authorization header value
   * @returns {string|null} Token or null
   */
  extractTokenFromHeader(authHeader) {
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return null;
    }
    return authHeader.substring(7);
  }

  /**
   * Refresh token pair using refresh token
   * @param {string} refreshToken - Refresh token
   * @returns {Object} New token pair
   */
  async refreshTokenPair(refreshToken) {
    try {
      const decoded = this.verifyToken(refreshToken, 'refresh');
      
      // Generate new token pair with the same user info
      // In a real app, you might want to fetch fresh user data
      const newTokenPair = this.generateTokenPair({
        sub: decoded.sub,
      });

      return newTokenPair;
    } catch (error) {
      logger.error('Token refresh failed', { error: error.message });
      throw new AuthenticationError('Invalid refresh token');
    }
  }
}

export default new TokenService();