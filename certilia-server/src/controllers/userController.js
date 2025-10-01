import certiliaService from '../services/certiliaService.js';
import logger from '../utils/logger.js';

/**
 * Get extended user information from Certilia API
 */
export const getExtendedUserInfo = async (req, res, next) => {
  try {
    // Check if Certilia tokens are in the decoded JWT payload
    const certiliaTokens = req.certilia_tokens;

    if (!certiliaTokens || !certiliaTokens.access_token) {
      // Log the actual JWT content for debugging
      logger.warn('No Certilia tokens found in JWT', {
        hasUser: !!req.user,
        userKeys: req.user ? Object.keys(req.user) : [],
        hasTokens: !!req.certilia_tokens
      });

      return res.status(400).json({
        error: 'No Certilia access token available',
        message: 'Please authenticate again to get a fresh token'
      });
    }

    let userInfo;
    let source = 'userinfo_endpoint';

    // Try to fetch extended user info from Certilia userinfo endpoint
    try {
      userInfo = await certiliaService.getUserInfo(
        certiliaTokens.access_token,
        certiliaTokens.id_token
      );

      logger.info('Extended user info fetched from userinfo endpoint', {
        fields: Object.keys(userInfo),
        sub: userInfo.sub
      });
    } catch (error) {
      // Check if this is specifically a token binding issue or if userinfo endpoint fails
      const shouldUseFallback =
        error.message === 'USE_ID_TOKEN_FALLBACK' ||
        error.response?.data?.error_description?.includes('token binding') ||
        error.response?.status === 400 ||
        error.message?.includes('invalid_request');

      if (shouldUseFallback) {
        logger.warn('Userinfo endpoint failed, using id_token claims as fallback', {
          error: error.message,
          status: error.response?.status,
          description: error.response?.data?.error_description
        });

        // Decode the id_token to get claims
        if (certiliaTokens.id_token) {
          try {
            const jwt = await import('jsonwebtoken');
            const decoded = jwt.default.decode(certiliaTokens.id_token);

            if (decoded) {
              // Extract relevant user info from ID token claims
              userInfo = {
                sub: decoded.sub,
                given_name: decoded.given_name,
                family_name: decoded.family_name,
                email: decoded.email,
                oib: decoded.oib,
                birthdate: decoded.birthdate,
                // Include any other available claims
                ...Object.keys(decoded).reduce((acc, key) => {
                  // Skip technical JWT claims
                  if (!['iss', 'aud', 'exp', 'iat', 'nbf', 'jti', 'auth_time', 'nonce', 'at_hash'].includes(key)) {
                    acc[key] = decoded[key];
                  }
                  return acc;
                }, {})
              };
              source = 'id_token_claims';

              logger.info('Using id_token claims for extended user info', {
                fields: Object.keys(userInfo),
                sub: userInfo.sub
              });
            } else {
              throw new Error('Failed to decode id_token');
            }
          } catch (decodeError) {
            logger.error('Failed to decode id_token', {
              error: decodeError.message
            });
            throw error; // Re-throw original error if fallback fails
          }
        } else {
          logger.error('No id_token available for fallback');
          throw error; // No id_token available for fallback
        }
      } else {
        // For other errors, just throw
        throw error;
      }
    }

    // Return all available user data
    res.json({
      userInfo,
      source, // Indicate where the data came from
      availableFields: Object.keys(userInfo),
      tokenExpiry: certiliaTokens.expires_in ?
        new Date(Date.now() + certiliaTokens.expires_in * 1000).toISOString() :
        null
    });
  } catch (error) {
    logger.error('Failed to fetch extended user info', {
      error: error.message,
      userId: req.user?.sub
    });
    next(error);
  }
};