import certiliaService from '../services/certiliaService.js';
import logger from '../utils/logger.js';

/**
 * Convert camelCase to snake_case
 */
const toSnakeCase = (str) => {
  return str.replace(/[A-Z]/g, letter => `_${letter.toLowerCase()}`);
};

/**
 * Convert object keys to snake_case recursively
 */
const convertKeysToSnakeCase = (obj) => {
  if (Array.isArray(obj)) {
    return obj.map(item => convertKeysToSnakeCase(item));
  } else if (obj !== null && typeof obj === 'object') {
    return Object.keys(obj).reduce((acc, key) => {
      const snakeKey = toSnakeCase(key);
      acc[snakeKey] = convertKeysToSnakeCase(obj[key]);
      return acc;
    }, {});
  }
  return obj;
};

/**
 * Get extended user information from Certilia API
 */
export const getExtendedUserInfo = async (req, res, next) => {
  try {
    console.log('DEBUG 1: getExtendedUserInfo called');

    // Check if Certilia tokens are in the decoded JWT payload
    const certiliaTokens = req.certilia_tokens;
    console.log('DEBUG 2: certiliaTokens present:', !!certiliaTokens);

    if (!certiliaTokens || !certiliaTokens.access_token) {
      console.log('DEBUG 3: No Certilia access token - returning 400');
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

    console.log('DEBUG 4: Has access_token:', !!certiliaTokens.access_token);
    console.log('DEBUG 5: Has id_token:', !!certiliaTokens.id_token);

    let userInfo;
    let source = 'userinfo_endpoint';
    const skipUserInfo = process.env.SKIP_USERINFO_ENDPOINT === 'true';
    console.log('DEBUG 6: skipUserInfo:', skipUserInfo);

    // Check if we should skip userinfo endpoint
    if (skipUserInfo) {
      console.log('DEBUG 7: Skipping userinfo endpoint, using JWT claims');
      // Use user data already in JWT (from ID token that was decoded during authentication)
      source = 'jwt_claims';
      logger.info('Skipping userinfo endpoint in production, using JWT claims');

      // User info is already in req.user from JWT
      if (req.user) {
        console.log('DEBUG 8: Using user data from JWT');
        console.log('DEBUG 9: JWT user keys:', Object.keys(req.user));

        // Extract ALL user info from JWT payload (already has ID token claims merged)
        // Start with spreading all user data, then override specific fields
        userInfo = Object.keys(req.user).reduce((acc, key) => {
          // Skip technical JWT fields, certilia_tokens, and thumbnail (will be added later)
          if (!['exp', 'iat', 'nbf', 'certilia_tokens', 'thumbnail'].includes(key)) {
            acc[key] = req.user[key];
          }
          return acc;
        }, {});

        // Ensure standard fields are properly mapped
        // Note: 'sub' is actually the OIB in Croatian eID
        userInfo.oib = userInfo.oib || userInfo.pin || userInfo.sub;
        userInfo.given_name = userInfo.given_name || userInfo.firstName;
        userInfo.family_name = userInfo.family_name || userInfo.lastName;

        console.log('DEBUG 10: userInfo built from JWT, keys:', Object.keys(userInfo));
        logger.info('Using JWT claims for extended user info', {
          fields: Object.keys(userInfo),
          sub: userInfo.sub
        });
      } else {
        console.log('DEBUG 11: No user data in JWT - returning 400');
        return res.status(400).json({
          error: 'No user data available',
          message: 'User data is missing from JWT token'
        });
      }
    } else {
      console.log('DEBUG 16: Not skipping userinfo, calling Certilia API');
      // Try to fetch extended user info from Certilia userinfo endpoint
      try {
        console.log('DEBUG 17: Calling certiliaService.getUserInfo');
        userInfo = await certiliaService.getUserInfo(
          certiliaTokens.access_token,
          certiliaTokens.id_token
        );
        console.log('DEBUG 18: getUserInfo returned, keys:', userInfo ? Object.keys(userInfo) : 'null');

        logger.info('Extended user info fetched from userinfo endpoint', {
          fields: Object.keys(userInfo),
          sub: userInfo.sub
        });
      } catch (error) {
        console.log('DEBUG 19: getUserInfo threw error:', error.message);
        // Check if this is specifically a token binding issue or if userinfo endpoint fails
        const shouldUseFallback =
          error.message === 'USE_ID_TOKEN_FALLBACK' ||
          error.response?.data?.error_description?.includes('token binding') ||
          error.response?.status === 400 ||
          error.message?.includes('invalid_request');

        console.log('DEBUG 20: shouldUseFallback:', shouldUseFallback);

        if (shouldUseFallback) {
          console.log('DEBUG 21: Using fallback to JWT claims');
          logger.warn('Userinfo endpoint failed, using JWT claims as fallback', {
            error: error.message,
            status: error.response?.status,
            description: error.response?.data?.error_description
          });

          // Use user data already in JWT (from ID token that was decoded during authentication)
          if (req.user) {
            console.log('DEBUG 22: Using user data from JWT for fallback');

            // Extract ALL user info from JWT payload (already has ID token claims merged)
            userInfo = Object.keys(req.user).reduce((acc, key) => {
              // Skip technical JWT fields, certilia_tokens, and thumbnail (will be added later)
              if (!['exp', 'iat', 'nbf', 'certilia_tokens', 'thumbnail'].includes(key)) {
                acc[key] = req.user[key];
              }
              return acc;
            }, {});

            // Ensure standard fields are properly mapped
            // Note: 'sub' is actually the OIB in Croatian eID
            userInfo.oib = userInfo.oib || userInfo.pin || userInfo.sub;
            userInfo.given_name = userInfo.given_name || userInfo.firstName;
            userInfo.family_name = userInfo.family_name || userInfo.lastName;
            source = 'jwt_claims_fallback';

            console.log('DEBUG 23: Fallback userInfo built from JWT, keys:', Object.keys(userInfo));
            logger.info('Using JWT claims for extended user info (fallback)', {
              fields: Object.keys(userInfo),
              sub: userInfo.sub
            });
          } else {
            console.log('DEBUG 24: No user data in JWT for fallback');
            logger.error('No user data available for fallback');
            throw error; // No user data available for fallback
          }
        } else {
          console.log('DEBUG 29: Not using fallback, re-throwing error');
          // For other errors, just throw
          throw error;
        }
      }
    }

    console.log('DEBUG 30: About to send response');
    console.log('DEBUG 31: userInfo keys:', userInfo ? Object.keys(userInfo) : 'null');
    console.log('DEBUG 32: source:', source);

    // Convert userInfo keys to snake_case for consistent API response
    const snakeCaseUserInfo = convertKeysToSnakeCase(userInfo);

    // Create available fields in snake_case
    const availableFieldsSnakeCase = Object.keys(snakeCaseUserInfo);

    // Return all available user data with snake_case keys (no thumbnail in extended-info)
    const responseData = {
      user_info: snakeCaseUserInfo,
      source, // Indicate where the data came from
      available_fields: availableFieldsSnakeCase,
      token_expiry: certiliaTokens.expires_in ?
        new Date(Date.now() + certiliaTokens.expires_in * 1000).toISOString() :
        null
    };

    console.log('DEBUG 33: Response data prepared, sending...');
    res.json(responseData);
    console.log('DEBUG 34: Response sent successfully');

  } catch (error) {
    console.log('DEBUG 35: Caught error:', error.message);
    logger.error('Failed to fetch extended user info', {
      error: error.message,
      userId: req.user?.sub
    });
    next(error);
  }
};