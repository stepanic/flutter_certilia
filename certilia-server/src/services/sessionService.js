import { v4 as uuidv4 } from 'uuid';
import logger from '../utils/logger.js';

// In-memory session store (replace with Redis in production)
class SessionService {
  constructor() {
    this.sessions = new Map();
    this.sessionTimeout = 10 * 60 * 1000; // 10 minutes
    
    // Clean up expired sessions every minute
    setInterval(() => this.cleanupExpiredSessions(), 60 * 1000);
  }

  /**
   * Create a new OAuth session
   * @param {Object} data - Session data
   * @returns {string} Session ID
   */
  createSession(data) {
    const sessionId = uuidv4();
    const session = {
      id: sessionId,
      ...data,
      createdAt: Date.now(),
      expiresAt: Date.now() + this.sessionTimeout,
    };

    this.sessions.set(sessionId, session);
    logger.debug('Session created', { sessionId });
    
    return sessionId;
  }

  /**
   * Get session by ID
   * @param {string} sessionId - Session ID
   * @returns {Object|null} Session data or null
   */
  getSession(sessionId) {
    const session = this.sessions.get(sessionId);
    
    if (!session) {
      return null;
    }

    // Check if session is expired
    if (session.expiresAt < Date.now()) {
      this.deleteSession(sessionId);
      return null;
    }

    return session;
  }

  /**
   * Update session data
   * @param {string} sessionId - Session ID
   * @param {Object} data - Data to update
   * @returns {boolean} Success status
   */
  updateSession(sessionId, data) {
    const session = this.getSession(sessionId);
    
    if (!session) {
      return false;
    }

    const updatedSession = {
      ...session,
      ...data,
      updatedAt: Date.now(),
    };

    this.sessions.set(sessionId, updatedSession);
    logger.debug('Session updated', { sessionId });
    
    return true;
  }

  /**
   * Delete session
   * @param {string} sessionId - Session ID
   * @returns {boolean} Success status
   */
  deleteSession(sessionId) {
    const result = this.sessions.delete(sessionId);
    if (result) {
      logger.debug('Session deleted', { sessionId });
    }
    return result;
  }

  /**
   * Clean up expired sessions
   */
  cleanupExpiredSessions() {
    const now = Date.now();
    let cleanedCount = 0;

    for (const [sessionId, session] of this.sessions) {
      if (session.expiresAt < now) {
        this.sessions.delete(sessionId);
        cleanedCount++;
      }
    }

    if (cleanedCount > 0) {
      logger.info('Cleaned up expired sessions', { count: cleanedCount });
    }
  }

  /**
   * Get session statistics
   * @returns {Object} Session statistics
   */
  getStats() {
    return {
      totalSessions: this.sessions.size,
      activeSessions: Array.from(this.sessions.values()).filter(
        session => session.expiresAt > Date.now()
      ).length,
    };
  }
}

export default new SessionService();