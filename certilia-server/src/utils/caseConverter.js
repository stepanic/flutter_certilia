/**
 * Utility functions for converting between camelCase and snake_case
 */

/**
 * Convert camelCase to snake_case
 * @param {string} str - String to convert
 * @returns {string} Snake case string
 */
export const toSnakeCase = (str) => {
  return str.replace(/[A-Z]/g, letter => `_${letter.toLowerCase()}`);
};

/**
 * Convert snake_case to camelCase
 * @param {string} str - String to convert
 * @returns {string} Camel case string
 */
export const toCamelCase = (str) => {
  return str.replace(/_([a-z])/g, (match, letter) => letter.toUpperCase());
};

/**
 * Convert object keys to snake_case recursively
 * @param {any} obj - Object to convert
 * @returns {any} Object with snake_case keys
 */
export const convertKeysToSnakeCase = (obj) => {
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
 * Convert object keys to camelCase recursively
 * @param {any} obj - Object to convert
 * @returns {any} Object with camelCase keys
 */
export const convertKeysToCamelCase = (obj) => {
  if (Array.isArray(obj)) {
    return obj.map(item => convertKeysToCamelCase(item));
  } else if (obj !== null && typeof obj === 'object') {
    return Object.keys(obj).reduce((acc, key) => {
      const camelKey = toCamelCase(key);
      acc[camelKey] = convertKeysToCamelCase(obj[key]);
      return acc;
    }, {});
  }
  return obj;
};