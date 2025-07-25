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

    // Fetch extended user info from Certilia
    const userInfo = await certiliaService.getUserInfo(
      certiliaTokens.access_token,
      certiliaTokens.id_token
    );

    // Log what data we received
    logger.info('Extended user info fetched', {
      fields: Object.keys(userInfo),
      sub: userInfo.sub
    });

    // Return all available user data
    res.json({
      userInfo,
      // Include any additional fields that might be available
      availableFields: Object.keys(userInfo),
      // Include token expiry info
      tokenExpiry: certiliaTokens.expires_in ? 
        new Date(Date.now() + certiliaTokens.expires_in * 1000).toISOString() : 
        null
    });
  } catch (error) {
    logger.error('Failed to fetch extended user info', {
      error: error.message,
      userId: req.user.sub
    });
    next(error);
  }
};