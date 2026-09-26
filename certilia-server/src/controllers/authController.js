import certiliaService from '../services/certiliaService.js';
import tokenService from '../services/tokenService.js';
import sessionService from '../services/sessionService.js';
import { convertKeysToSnakeCase } from '../utils/caseConverter.js';
import { generateRandomString, generatePKCEChallenge, generatePKCEVerifier, generateState, generateNonce } from '../utils/crypto.js';
import logger from '../utils/logger.js';
import { AuthenticationError, ValidationError } from '../utils/errors.js';
import { getBranding } from '../config/branding.js';
import { config } from '../config/index.js';
import { resolveClientByRedirectUri, resolveClientById } from '../config/clients.js';
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
  // Branding iz env varijabli ulazi u svaki render; data ne sadrži brand* ključeve.
  data = { ...getBranding(), ...data };

  // Position of the {{/if}} that closes the {{#if}} opened just before
  // startPos, or -1.
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
 * Initialize OAuth authorization flow.
 * The SDK calls this on every platform to get the authorization URL.
 */
export const initializeAuth = async (req, res, next) => {
  try {
    const { redirect_uri, state: clientState } = req.query;

    const state = clientState || generateState();
    const nonce = generateNonce();
    const codeVerifier = generatePKCEVerifier();
    const codeChallenge = generatePKCEChallenge(codeVerifier);

    // Each Certilia client has exactly one callback URL, so the redirect_uri
    // decides which client this login uses.
    const client = resolveClientByRedirectUri(config.certilia.clients, redirect_uri);

    const sessionId = sessionService.createSession({
      state,
      nonce,
      codeVerifier,
      redirectUri: redirect_uri,
      clientId: client.clientId,
      createdAt: new Date().toISOString(),
    });

    const authorizationUrl = certiliaService.buildAuthorizationUrl({
      state,
      nonce,
      codeChallenge,
      redirectUri: redirect_uri,
      client,
    });

    logger.info('OAuth flow initialized', { sessionId, clientId: client.clientId });

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
 * Handle OAuth callback from Certilia.
 * Certilia redirects the browser here after login in the mobile WebView flow,
 * which reads the code from this URL. The page keeps the code in the browser
 * that logged in: the proxy stores nothing and hands it to no one else, so a
 * login someone else started gives them nothing.
 */
export const handleCallback = async (req, res, next) => {
  try {
    const { code, state } = req.query;
    const { error, error_description } = req.query;

    // Debug logging
    logger.info('===== OAUTH CALLBACK RECEIVED =====');
    logger.info('Full query params:', req.query);
    logger.info('Code:', code || 'null');
    logger.info('State:', state || 'null');
    logger.info('Error:', error || 'null');
    logger.info('Error Description:', error_description || 'null');
    logger.info('Request headers:', req.headers);
    logger.info('Request URL:', req.url);

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

    const branding = getBranding();
    const templateData = {
      success: true,
      title: branding.brandSuccessTitle,
      message: branding.brandSuccessMessage,
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
      showCloseButton: true, // Always show close button for successful auth
    };

    logger.info('Rendering success callback template with data:', templateData);
    
    res.send(renderCallbackTemplate(templateData));
  } catch (error) {
    next(error);
  }
};

/**
 * Exchange authorization code for tokens.
 * The SDK calls this with the code from the callback, on every platform.
 */
export const exchangeCode = async (req, res, next) => {
  try {
    const { code, state, session_id } = req.body;

    const session = sessionService.getSession(session_id);
    if (!session) {
      throw new AuthenticationError('Invalid or expired session');
    }

    if (session.state !== state) {
      throw new AuthenticationError('Invalid state parameter');
    }

    const tokenResponse = await certiliaService.exchangeCodeForTokens({
      code,
      codeVerifier: session.codeVerifier,
      redirectUri: session.redirectUri,
      client: resolveClientById(config.certilia.clients, session.clientId),
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

    let idTokenClaims = {};
    let thumbnail = null; // Store thumbnail separately to add to response later
    if (tokenResponse.id_token) {
      try {
        const decoded = tokenService.decodeToken(tokenResponse.id_token);

        // Validate nonce if present
        if (decoded.nonce && decoded.nonce !== session.nonce) {
          throw new AuthenticationError('Invalid nonce in ID token');
        }

        // Extract and store thumbnail separately, remove from JWT to reduce size
        thumbnail = decoded.thumbnail;
        const { thumbnail: _, ...decodedWithoutThumbnail } = decoded;

        idTokenClaims = decodedWithoutThumbnail;

        logger.info('ID token decoded successfully', {
          sub: decoded.sub,
          name: decoded.name,
          given_name: decoded.given_name,
          family_name: decoded.family_name,
          email: decoded.email,
          iss: decoded.iss,
          aud: decoded.aud,
          hasThumbnail: !!thumbnail,
          thumbnailSize: thumbnail ? thumbnail.length : 0,
          allFields: Object.keys(decoded)
        });

        // Debug: Log all available fields in ID token (excluding thumbnail)
        logger.debug('All ID token claims:', {
          availableFields: Object.keys(decoded),
          allClaimsExceptThumbnail: decodedWithoutThumbnail
        });
      } catch (error) {
        logger.error('Failed to decode ID token:', error);
        throw error;
      }
    }
    
    // Try to get user info from userinfo endpoint (unless disabled)
    let userInfo = {};
    const skipUserInfo = process.env.SKIP_USERINFO_ENDPOINT === 'true';

    if (skipUserInfo) {
      // Certilia's production userinfo endpoint only answers requests that carry
      // the `atbv` token-binding cookie of the browser that logged in, so a call
      // from this server always fails there.
      logger.info('Skipping userinfo endpoint, using ID token claims directly');
      if (idTokenClaims && idTokenClaims.sub) {
        userInfo = {
          sub: idTokenClaims.sub,
          given_name: idTokenClaims.given_name,
          family_name: idTokenClaims.family_name,
          firstName: idTokenClaims.given_name,  // Keep both for compatibility
          lastName: idTokenClaims.family_name,   // Keep both for compatibility
          fullName: idTokenClaims.name || `${idTokenClaims.given_name || ''} ${idTokenClaims.family_name || ''}`.trim(),
          email: idTokenClaims.email,
          oib: idTokenClaims.pin || idTokenClaims.oib,
          birthdate: idTokenClaims.birthdate,
          dateOfBirth: idTokenClaims.birthdate,  // Keep both for compatibility
          // Include all other claims (thumbnail already removed)
          ...idTokenClaims
        };
      } else {
        throw new Error('No ID token claims available');
      }
    } else {
      // Try to fetch from userinfo endpoint
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
            given_name: idTokenClaims.given_name,
            family_name: idTokenClaims.family_name,
            firstName: idTokenClaims.given_name,  // Keep both for compatibility
            lastName: idTokenClaims.family_name,   // Keep both for compatibility
            fullName: idTokenClaims.name || `${idTokenClaims.given_name || ''} ${idTokenClaims.family_name || ''}`.trim(),
            email: idTokenClaims.email,
            oib: idTokenClaims.pin || idTokenClaims.oib,
            birthdate: idTokenClaims.birthdate,
            dateOfBirth: idTokenClaims.birthdate,  // Keep both for compatibility
            // Include all other claims (thumbnail already removed)
            ...idTokenClaims
          };
        } else {
          throw error;
        }
      }
    }

    // The proxy's JWT carries Certilia's access and refresh tokens but not the
    // ID token: that holds the user's photo (the thumbnail claim) and would
    // make the Authorization header too large.
    const certiliaTokensForJWT = {
      access_token: certiliaTokens.access_token,
      refresh_token: certiliaTokens.refresh_token,
      expires_in: certiliaTokens.expires_in,
      token_type: certiliaTokens.token_type
    };

    // Merge user info and id token claims
    const mergedUserInfo = {
      ...userInfo,
      ...idTokenClaims,
    };

    // The JWT carries all user data with snake_case keys.
    const snakeCaseUserInfo = convertKeysToSnakeCase(mergedUserInfo);

    // Add certilia tokens (already in snake_case)
    const completeUserInfo = {
      ...snakeCaseUserInfo,
      certilia_tokens: certiliaTokensForJWT, // Store tokens without ID token
    };

    // Debug: Log what we're putting in JWT
    logger.debug('Creating JWT with user info:', {
      userInfoKeys: Object.keys(userInfo),
      idTokenClaimsKeys: Object.keys(idTokenClaims),
      completeUserInfoKeys: Object.keys(completeUserInfo),
      hasbirthdate: !!completeUserInfo.birthdate,
      hasMobile: !!completeUserInfo.mobile,
      hasFormatted: !!completeUserInfo.formatted,
      hasGender: !!completeUserInfo.gender
    });

    const tokens = tokenService.generateTokenPair(completeUserInfo);

    sessionService.deleteSession(session_id);

    logger.info('Code exchanged successfully', {
      userId: userInfo.sub,
      hasThumbnailInResponse: thumbnail !== null && thumbnail !== undefined,
      thumbnailLength: thumbnail ? thumbnail.length : 0
    });

    res.json({
      ...tokens,
      // Certilijin OIDC id_token, pod camelCase ključem koji čita SDK-ov
      // `_tokenFromResponse`. Aplikacija ga može poslati svom backendu, koji ga
      // provjerava prema Certilijinom JWKS-u. U JWT proxyja ne ulazi (vidi
      // gore), pa se vraća kao zasebno polje.
      idToken: certiliaTokens.id_token,
      user: {
        sub: userInfo.sub,
        first_name: userInfo.firstName || userInfo.given_name,
        last_name: userInfo.lastName || userInfo.family_name,
        oib: userInfo.oib,
        email: userInfo.email,
        date_of_birth: userInfo.dateOfBirth || userInfo.birthdate,
        thumbnail: thumbnail ?? null, // Include thumbnail in response but not in JWT
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
    const { refresh_token, access_token: bodyAccessToken } = req.body;

    if (!refresh_token) {
      throw new ValidationError('Refresh token is required');
    }

    // Verify and decode refresh token
    const decoded = tokenService.verifyToken(refresh_token, 'refresh');

    // Prefer access_token from the body; SDK versions before 0.2.0 send it in
    // the Authorization header instead.
    let accessToken = bodyAccessToken;
    if (!accessToken) {
      accessToken = tokenService.extractTokenFromHeader(req.headers.authorization);
    }

    // The new access token carries the user's claims over from the old one.
    // Its signature is checked first, and it must belong to the same user as
    // the refresh token; otherwise anyone holding a refresh token could have
    // arbitrary claims (name, OIB, certilia_tokens) signed.
    let userData = { sub: decoded.sub };
    if (accessToken) {
      const accessDecoded = tokenService.verifyExpiredAccessToken(accessToken);
      if (accessDecoded.sub !== decoded.sub) {
        throw new AuthenticationError('Access token belongs to another user');
      }
      const { type, ...claims } = accessDecoded;
      userData = claims;
    }

    const tokens = tokenService.generateTokenPair(userData);

    logger.info('Token refreshed', {
      userId: decoded.sub,
      hasCertiliaTokens: !!userData.certilia_tokens,
    });

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
    // Already in snake_case from JWT, but ensure consistency
    res.json({
      user: convertKeysToSnakeCase(req.user),
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
    // The proxy keeps no state for a login once the code is exchanged, and it
    // does not revoke its JWTs, so logout only logs. The access and refresh
    // tokens stay valid until they expire.

    logger.info('User logged out', { userId: req.userId });

    res.json({
      message: 'Logged out successfully',
    });
  } catch (error) {
    next(error);
  }
};
