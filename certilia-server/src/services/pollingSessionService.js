import crypto from 'crypto';
import logger from '../utils/logger.js';

/**
 * In-memory store for polling sessions
 * Structure: Map<pollingId, sessionData>
 */
const pollingSessions = new Map();

/**
 * Session cleanup interval - remove expired sessions every 5 minutes
 */
const CLEANUP_INTERVAL = 5 * 60 * 1000; // 5 minutes
const SESSION_TTL = 10 * 60 * 1000; // 10 minutes

/**
 * Polling session service for cross-origin authentication
 */
class PollingSessionService {
  constructor() {
    // Start cleanup interval
    this.cleanupInterval = setInterval(() => {
      this.cleanup();
    }, CLEANUP_INTERVAL);
  }

  /**
   * Create a new polling session
   * @param {Object} data - Initial session data
   * @returns {Object} Session info with polling ID
   */
  createSession(data = {}) {
    const pollingId = crypto.randomBytes(32).toString('hex');
    const session = {
      pollingId,
      status: 'pending',
      createdAt: Date.now(),
      expiresAt: Date.now() + SESSION_TTL,
      ...data,
      // Authentication result will be stored here
      result: null,
    };

    pollingSessions.set(pollingId, session);
    
    logger.info('Created polling session', {
      pollingId,
      state: data.state,
      sessionId: data.sessionId,
    });

    return {
      pollingId,
      expiresAt: session.expiresAt,
    };
  }

  /**
   * Get session by polling ID
   * @param {string} pollingId
   * @returns {Object|null} Session data or null if not found/expired
   */
  getSession(pollingId) {
    const session = pollingSessions.get(pollingId);
    
    if (!session) {
      return null;
    }

    // Check if expired
    if (Date.now() > session.expiresAt) {
      pollingSessions.delete(pollingId);
      return null;
    }

    return session;
  }

  /**
   * Update session with authentication result
   * @param {string} state - OAuth state parameter
   * @param {Object} result - Authentication result
   * @returns {boolean} True if session was updated
   */
  updateSessionByState(state, result) {
    let updated = false;
    
    // Find session by state
    for (const [pollingId, session] of pollingSessions.entries()) {
      if (session.state === state && session.status === 'pending') {
        session.status = result.error ? 'error' : 'completed';
        session.result = result;
        session.completedAt = Date.now();
        
        logger.info('Updated polling session', {
          pollingId,
          state,
          status: session.status,
          hasCode: !!result.code,
          error: result.error,
        });
        
        updated = true;
        break;
      }
    }

    return updated;
  }

  /**
   * Get session status for polling
   * @param {string} pollingId
   * @returns {Object} Status object
   */
  getStatus(pollingId) {
    const session = this.getSession(pollingId);
    
    if (!session) {
      return {
        status: 'not_found',
        error: 'Session not found or expired',
      };
    }

    const response = {
      status: session.status,
      createdAt: session.createdAt,
      expiresAt: session.expiresAt,
    };

    // Include result if completed
    if (session.status === 'completed' && session.result) {
      response.result = {
        code: session.result.code,
        state: session.result.state,
      };
    } else if (session.status === 'error' && session.result) {
      response.error = session.result.error;
      response.errorDescription = session.result.errorDescription;
    }

    return response;
  }

  /**
   * Clean up expired sessions
   */
  cleanup() {
    const now = Date.now();
    let cleaned = 0;

    for (const [pollingId, session] of pollingSessions.entries()) {
      if (now > session.expiresAt) {
        pollingSessions.delete(pollingId);
        cleaned++;
      }
    }

    if (cleaned > 0) {
      logger.info(`Cleaned up ${cleaned} expired polling sessions`);
    }
  }

  /**
   * Get statistics about polling sessions
   */
  getStats() {
    const now = Date.now();
    const sessions = Array.from(pollingSessions.values());
    
    return {
      total: sessions.length,
      pending: sessions.filter(s => s.status === 'pending').length,
      completed: sessions.filter(s => s.status === 'completed').length,
      error: sessions.filter(s => s.status === 'error').length,
      expired: sessions.filter(s => now > s.expiresAt).length,
    };
  }

  /**
   * Shutdown service
   */
  shutdown() {
    if (this.cleanupInterval) {
      clearInterval(this.cleanupInterval);
    }
    pollingSessions.clear();
  }
}

// Export singleton instance
export default new PollingSessionService();