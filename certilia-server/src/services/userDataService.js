import logger from '../utils/logger.js';

/**
 * Service for storing user-specific data that shouldn't be in JWT
 * In production, this should use Redis or a database
 */
class UserDataService {
  constructor() {
    // In-memory store for user thumbnails and other large data
    this.userThumbnails = new Map();
    this.dataTimeout = 24 * 60 * 60 * 1000; // 24 hours

    // Clean up old data every hour
    setInterval(() => this.cleanupOldData(), 60 * 60 * 1000);
  }

  /**
   * Store user thumbnail
   * @param {string} userId - User ID (sub)
   * @param {string} thumbnail - Base64 encoded thumbnail
   */
  setUserThumbnail(userId, thumbnail) {
    if (!userId || !thumbnail) return;

    this.userThumbnails.set(userId, {
      thumbnail,
      storedAt: Date.now(),
      expiresAt: Date.now() + this.dataTimeout
    });

    logger.info('User thumbnail stored', {
      userId,
      thumbnailSize: thumbnail.length
    });
  }

  /**
   * Get user thumbnail
   * @param {string} userId - User ID (sub)
   * @returns {string|null} Thumbnail or null
   */
  getUserThumbnail(userId) {
    const data = this.userThumbnails.get(userId);

    if (!data) {
      return null;
    }

    // Check if data is expired
    if (data.expiresAt < Date.now()) {
      this.userThumbnails.delete(userId);
      return null;
    }

    return data.thumbnail;
  }

  /**
   * Delete user thumbnail
   * @param {string} userId - User ID (sub)
   */
  deleteUserThumbnail(userId) {
    const result = this.userThumbnails.delete(userId);
    if (result) {
      logger.debug('User thumbnail deleted', { userId });
    }
    return result;
  }

  /**
   * Clean up old data
   */
  cleanupOldData() {
    const now = Date.now();
    let cleanedCount = 0;

    for (const [userId, data] of this.userThumbnails) {
      if (data.expiresAt < now) {
        this.userThumbnails.delete(userId);
        cleanedCount++;
      }
    }

    if (cleanedCount > 0) {
      logger.info('Cleaned up old user thumbnails', { count: cleanedCount });
    }
  }

  /**
   * Get statistics
   * @returns {Object} Statistics
   */
  getStats() {
    return {
      totalThumbnails: this.userThumbnails.size,
      totalMemoryUsage: Array.from(this.userThumbnails.values())
        .reduce((sum, data) => sum + (data.thumbnail?.length || 0), 0)
    };
  }
}

export default new UserDataService();