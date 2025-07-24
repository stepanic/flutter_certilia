import crypto from 'crypto';

/**
 * Generate a cryptographically secure random string
 * @param {number} length - Length of the string to generate
 * @returns {string} Random string
 */
export function generateRandomString(length = 32) {
  return crypto.randomBytes(length).toString('base64url');
}

/**
 * Generate PKCE challenge from verifier
 * @param {string} verifier - PKCE verifier
 * @returns {string} Base64url encoded challenge
 */
export function generatePKCEChallenge(verifier) {
  return crypto
    .createHash('sha256')
    .update(verifier)
    .digest('base64url');
}

/**
 * Verify PKCE challenge
 * @param {string} verifier - PKCE verifier
 * @param {string} challenge - PKCE challenge
 * @returns {boolean} True if valid
 */
export function verifyPKCEChallenge(verifier, challenge) {
  const expectedChallenge = generatePKCEChallenge(verifier);
  return expectedChallenge === challenge;
}

/**
 * Hash a password using crypto
 * @param {string} password - Password to hash
 * @param {string} salt - Salt for hashing
 * @returns {string} Hashed password
 */
export function hashPassword(password, salt = generateRandomString(16)) {
  return crypto
    .pbkdf2Sync(password, salt, 10000, 64, 'sha512')
    .toString('hex');
}

/**
 * Generate a secure state parameter for OAuth
 * @returns {string} State parameter
 */
export function generateState() {
  return generateRandomString(32);
}

/**
 * Generate a nonce for OpenID Connect
 * @returns {string} Nonce
 */
export function generateNonce() {
  return generateRandomString(32);
}