import axios from 'axios';
import { config } from '../config/index.js';
import logger from '../utils/logger.js';
import { ExternalServiceError } from '../utils/errors.js';

class CertiliaService {
  constructor() {
    this.client = axios.create({
      baseURL: config.certilia.baseUrl,
      timeout: 30000,
      headers: {
        'User-Agent': 'CertiliaServer/1.0.0',
      },
    });

    // Add request interceptor for logging
    this.client.interceptors.request.use(
      (request) => {
        logger.debug('Certilia API Request', {
          method: request.method,
          url: request.url,
          headers: request.headers,
        });
        return request;
      },
      (error) => {
        logger.error('Certilia API Request Error', { error: error.message });
        return Promise.reject(error);
      }
    );

    // Add response interceptor for logging
    this.client.interceptors.response.use(
      (response) => {
        logger.debug('Certilia API Response', {
          status: response.status,
          statusText: response.statusText,
        });
        return response;
      },
      (error) => {
        logger.error('Certilia API Response Error', {
          status: error.response?.status,
          statusText: error.response?.statusText,
          data: error.response?.data,
        });
        return Promise.reject(error);
      }
    );
  }

  /**
   * Get OpenID Connect discovery configuration
   */
  async getDiscoveryConfiguration() {
    try {
      const response = await this.client.get(config.certilia.discoveryEndpoint);
      return response.data;
    } catch (error) {
      throw new ExternalServiceError(
        'Failed to fetch discovery configuration',
        'certilia'
      );
    }
  }

  /**
   * Build authorization URL for OAuth flow
   * @param {Object} params - Authorization parameters
   * @param {string} params.state - State parameter
   * @param {string} params.nonce - Nonce parameter
   * @param {string} params.codeChallenge - PKCE code challenge
   * @param {string} params.redirectUri - Redirect URI
   * @returns {string} Authorization URL
   */
  buildAuthorizationUrl({
    state,
    nonce,
    codeChallenge,
    redirectUri = config.certilia.redirectUri,
  }) {
    const params = new URLSearchParams({
      client_id: config.certilia.clientId,
      redirect_uri: redirectUri,
      response_type: 'code',
      scope: config.certilia.scopes.join(' '),
      state,
      nonce,
      code_challenge: codeChallenge,
      code_challenge_method: 'S256',
      prompt: 'login',
    });

    return `${config.certilia.baseUrl}${config.certilia.authEndpoint}?${params.toString()}`;
  }

  /**
   * Exchange authorization code for tokens
   * @param {Object} params - Token exchange parameters
   * @param {string} params.code - Authorization code
   * @param {string} params.codeVerifier - PKCE code verifier
   * @param {string} params.redirectUri - Redirect URI
   * @returns {Promise<Object>} Token response
   */
  async exchangeCodeForTokens({ code, codeVerifier, redirectUri = config.certilia.redirectUri }) {
    try {
      const params = new URLSearchParams({
        grant_type: 'authorization_code',
        client_id: config.certilia.clientId,
        client_secret: config.certilia.clientSecret,
        code,
        redirect_uri: redirectUri,
        code_verifier: codeVerifier,
      });

      const response = await this.client.post(
        config.certilia.tokenEndpoint,
        params.toString(),
        {
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
          },
        }
      );

      return response.data;
    } catch (error) {
      if (error.response?.status === 400) {
        throw new ExternalServiceError(
          error.response.data.error_description || 'Invalid authorization code',
          'certilia'
        );
      }
      throw new ExternalServiceError(
        'Failed to exchange code for tokens',
        'certilia'
      );
    }
  }

  /**
   * Refresh access token
   * @param {string} refreshToken - Refresh token
   * @returns {Promise<Object>} Token response
   */
  async refreshAccessToken(refreshToken) {
    try {
      const params = new URLSearchParams({
        grant_type: 'refresh_token',
        client_id: config.certilia.clientId,
        client_secret: config.certilia.clientSecret,
        refresh_token: refreshToken,
      });

      const response = await this.client.post(
        config.certilia.tokenEndpoint,
        params.toString(),
        {
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
          },
        }
      );

      return response.data;
    } catch (error) {
      if (error.response?.status === 400) {
        throw new ExternalServiceError(
          'Invalid refresh token',
          'certilia'
        );
      }
      throw new ExternalServiceError(
        'Failed to refresh access token',
        'certilia'
      );
    }
  }

  /**
   * Get user information
   * @param {string} accessToken - Access token
   * @returns {Promise<Object>} User information
   */
  async getUserInfo(accessToken) {
    try {
      const response = await this.client.get(config.certilia.userInfoEndpoint, {
        headers: {
          Authorization: `Bearer ${accessToken}`,
        },
      });

      return response.data;
    } catch (error) {
      if (error.response?.status === 401) {
        throw new ExternalServiceError(
          'Invalid or expired access token',
          'certilia'
        );
      }
      throw new ExternalServiceError(
        'Failed to fetch user information',
        'certilia'
      );
    }
  }

  /**
   * Revoke token
   * @param {string} token - Token to revoke
   * @param {string} tokenType - Type of token (access_token or refresh_token)
   * @returns {Promise<void>}
   */
  async revokeToken(token, tokenType = 'access_token') {
    try {
      const params = new URLSearchParams({
        token,
        token_type_hint: tokenType,
        client_id: config.certilia.clientId,
        client_secret: config.certilia.clientSecret,
      });

      await this.client.post(
        '/oauth/revoke',
        params.toString(),
        {
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
          },
        }
      );
    } catch (error) {
      // Token revocation failures are often not critical
      logger.warn('Failed to revoke token', {
        tokenType,
        error: error.message,
      });
    }
  }
}

export default new CertiliaService();