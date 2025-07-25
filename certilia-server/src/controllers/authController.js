import certiliaService from '../services/certiliaService.js';
import tokenService from '../services/tokenService.js';
import sessionService from '../services/sessionService.js';
import { generateRandomString, generatePKCEChallenge, generatePKCEVerifier, generateState, generateNonce } from '../utils/crypto.js';
import logger from '../utils/logger.js';
import { AuthenticationError, ValidationError } from '../utils/errors.js';
import { readFileSync } from 'fs';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// Load callback template
const callbackTemplate = readFileSync(
  join(__dirname, '../templates/callback.html'),
  'utf8'
);

/**
 * Render callback template with data
 */
function renderCallbackTemplate(data) {
  let html = callbackTemplate;
  
  // Function to find matching endif for a given if position
  function findMatchingEndIf(str, startPos) {
    let depth = 1;
    let pos = startPos;
    
    while (depth > 0 && pos < str.length) {
      const nextIf = str.indexOf('{{#if', pos);
      const nextEndIf = str.indexOf('{{/if}}', pos);
      
      if (nextEndIf === -1) return -1;
      
      if (nextIf !== -1 && nextIf < nextEndIf) {
        depth++;
        pos = nextIf + 5;
      } else {
        depth--;
        if (depth === 0) return nextEndIf;
        pos = nextEndIf + 7;
      }
    }
    
    return -1;
  }
  
  // Process conditionals from outside to inside
  let processed = true;
  while (processed) {
    processed = false;
    
    const match = html.match(/\{\{#if\s+(\w+)\}\}/);
    if (match) {
      const startPos = match.index;
      const condition = match[1];
      const endIfPos = findMatchingEndIf(html, startPos + match[0].length);
      
      if (endIfPos !== -1) {
        const beforeIf = html.substring(0, startPos);
        const content = html.substring(startPos + match[0].length, endIfPos);
        const afterIf = html.substring(endIfPos + 7);
        
        if (data[condition]) {
          html = beforeIf + content + afterIf;
        } else {
          html = beforeIf + afterIf;
        }
        processed = true;
      }
    }
  }
  
  // Replace all template variables
  Object.keys(data).forEach(key => {
    const value = data[key] === null ? '' : data[key];
    html = html.replace(new RegExp(`\\{\\{${key}\\}\\}`, 'g'), value);
  });
  
  return html;
}

/**
 * Initialize OAuth authorization flow
 * Mobile app calls this to get authorization URL
 */
export const initializeAuth = async (req, res, next) => {
  try {
    const { redirect_uri, state: clientState } = req.query;

    // Generate OAuth parameters
    const state = clientState || generateState();
    const nonce = generateNonce();
    const codeVerifier = generatePKCEVerifier();
    const codeChallenge = generatePKCEChallenge(codeVerifier);

    // Create session to store OAuth parameters
    const sessionId = sessionService.createSession({
      state,
      nonce,
      codeVerifier,
      redirectUri: redirect_uri,
      createdAt: new Date().toISOString(),
    });

    // Build authorization URL
    const authorizationUrl = certiliaService.buildAuthorizationUrl({
      state,
      nonce,
      codeChallenge,
      redirectUri: redirect_uri,
    });

    logger.info('OAuth flow initialized', { sessionId });

    res.json({
      authorization_url: authorizationUrl,
      session_id: sessionId,
      state,
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Handle OAuth callback from Certilia
 * This is called by Certilia after user authentication
 */
export const handleCallback = async (req, res, next) => {
  try {
    const { code, state } = req.query;
    const { error, error_description } = req.query;

    // Check for OAuth errors
    if (error) {
      logger.warn('OAuth callback error', { error, error_description });
      
      const errorData = {
        success: false,
        title: 'Authentication Failed',
        message: error_description || 'An error occurred during authentication.',
        icon: 'X',
        iconClass: 'error',
        code: null,
        state: state || '',
        error: error,
        errorDescription: error_description || '',
        showCode: 'none',
        showCodeContainer: false,
        showButton: true,
        buttonText: 'Try Again',
        buttonLink: '/',
        deepLink: null,
      };
      
      return res.send(renderCallbackTemplate(errorData));
    }

    if (!code || !state) {
      throw new ValidationError('Missing required parameters');
    }

    // Build response data
    const templateData = {
      success: true,
      title: 'Authentication Successful',
      message: 'You can close this window and return to the app.',
      icon: 'OK',
      iconClass: 'success',
      code: code || '',
      state: state || '',
      error: null,
      errorDescription: null,
      showCode: 'none', // Hide code in UI for security
      showCodeContainer: false,
      showButton: false,
      buttonText: '',
      buttonLink: '/',
      deepLink: null, // Could be configured for specific apps
    };

    // For mobile apps, return an HTML page that can be parsed
    res.send(renderCallbackTemplate(templateData));
  } catch (error) {
    next(error);
  }
};

/**
 * Exchange authorization code for tokens
 * Mobile app calls this after parsing the callback
 */
export const exchangeCode = async (req, res, next) => {
  try {
    const { code, state, session_id } = req.body;

    // Retrieve session
    const session = sessionService.getSession(session_id);
    if (!session) {
      throw new AuthenticationError('Invalid or expired session');
    }

    // Verify state
    if (session.state !== state) {
      throw new AuthenticationError('Invalid state parameter');
    }

    // Exchange code for tokens
    const tokenResponse = await certiliaService.exchangeCodeForTokens({
      code,
      codeVerifier: session.codeVerifier,
      redirectUri: session.redirectUri,
    });
    
    logger.info('Token exchange response:', {
      hasAccessToken: !!tokenResponse.access_token,
      hasRefreshToken: !!tokenResponse.refresh_token,
      hasIdToken: !!tokenResponse.id_token,
      expiresIn: tokenResponse.expires_in,
      tokenType: tokenResponse.token_type,
      scope: tokenResponse.scope
    });

    // Store the original tokens from Certilia
    const certiliaTokens = {
      access_token: tokenResponse.access_token,
      refresh_token: tokenResponse.refresh_token,
      id_token: tokenResponse.id_token,
      expires_in: tokenResponse.expires_in,
    };

    // First decode ID token to get claims
    let idTokenClaims = {};
    if (tokenResponse.id_token) {
      try {
        const decoded = tokenService.decodeToken(tokenResponse.id_token);
        
        // Validate nonce if present
        if (decoded.nonce && decoded.nonce !== session.nonce) {
          throw new AuthenticationError('Invalid nonce in ID token');
        }
        
        idTokenClaims = decoded;
        logger.info('ID token decoded successfully', {
          sub: decoded.sub,
          name: decoded.name,
          given_name: decoded.given_name,
          family_name: decoded.family_name,
          email: decoded.email,
          iss: decoded.iss,
          aud: decoded.aud
        });
      } catch (error) {
        logger.error('Failed to decode ID token:', error);
        throw error;
      }
    }
    
    // Try to get user info from userinfo endpoint
    let userInfo = {};
    try {
      userInfo = await certiliaService.getUserInfo(
        tokenResponse.access_token,
        tokenResponse.id_token
      );
      logger.info('UserInfo endpoint succeeded');
    } catch (error) {
      logger.warn('UserInfo endpoint failed:', error.message);
      // If userinfo fails but we have ID token claims, use them
      if (idTokenClaims && idTokenClaims.sub) {
        logger.info('Using ID token claims as fallback');
        userInfo = {
          sub: idTokenClaims.sub,
          firstName: idTokenClaims.given_name,
          lastName: idTokenClaims.family_name,
          fullName: idTokenClaims.name || `${idTokenClaims.given_name || ''} ${idTokenClaims.family_name || ''}`.trim(),
          email: idTokenClaims.email,
          oib: idTokenClaims.pin || idTokenClaims.oib,
          dateOfBirth: idTokenClaims.birthdate,
          // Include all other claims
          ...idTokenClaims
        };
      } else {
        throw error;
      }
    }

    // Merge any additional ID token claims with user info
    // (ID token was already decoded above)

    // Generate our own JWT tokens with complete user data
    const completeUserInfo = {
      ...userInfo,
      ...idTokenClaims,
      certilia_tokens: certiliaTokens, // Store original tokens for potential future use
    };

    const tokens = tokenService.generateTokenPair(completeUserInfo);

    // Clean up session
    sessionService.deleteSession(session_id);

    logger.info('Code exchanged successfully', { userId: userInfo.sub });

    res.json({
      ...tokens,
      user: {
        sub: userInfo.sub,
        firstName: userInfo.given_name,
        lastName: userInfo.family_name,
        oib: userInfo.oib,
        email: userInfo.email,
        dateOfBirth: userInfo.birthdate,
      },
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Refresh access token
 */
export const refreshToken = async (req, res, next) => {
  try {
    const { refresh_token } = req.body;

    if (!refresh_token) {
      throw new ValidationError('Refresh token is required');
    }

    // Verify and decode refresh token
    const decoded = tokenService.verifyToken(refresh_token, 'refresh');

    // In a real app, you might want to check if the user still exists
    // and fetch fresh user data from database

    // Generate new token pair
    const tokens = tokenService.generateTokenPair({
      sub: decoded.sub,
    });

    logger.info('Token refreshed', { userId: decoded.sub });

    res.json(tokens);
  } catch (error) {
    next(error);
  }
};

/**
 * Get current user info from token
 */
export const getCurrentUser = async (req, res, next) => {
  try {
    // User info is attached by auth middleware
    res.json({
      user: req.user,
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Logout user
 */
export const logout = async (req, res, next) => {
  try {
    // In a real app, you might want to:
    // - Invalidate the refresh token
    // - Add the access token to a blacklist
    // - Clear any server-side sessions

    logger.info('User logged out', { userId: req.userId });

    res.json({
      message: 'Logged out successfully',
    });
  } catch (error) {
    next(error);
  }
};