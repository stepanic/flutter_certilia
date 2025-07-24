import Joi from 'joi';
import { ValidationError } from '../utils/errors.js';

/**
 * Validation middleware factory
 * @param {Object} schema - Joi validation schema
 * @param {string} property - Request property to validate (body, query, params)
 * @returns {Function} Express middleware
 */
export const validate = (schema, property = 'body') => {
  return (req, res, next) => {
    const { error, value } = schema.validate(req[property], {
      abortEarly: false,
      stripUnknown: true,
    });

    if (error) {
      const errors = error.details.map(detail => ({
        field: detail.path.join('.'),
        message: detail.message,
      }));

      return next(new ValidationError('Validation failed', errors));
    }

    // Replace request property with validated value
    req[property] = value;
    next();
  };
};

// Common validation schemas
export const schemas = {
  // OAuth authorization request
  authorizationRequest: Joi.object({
    response_type: Joi.string().valid('code').required(),
    redirect_uri: Joi.string().uri().required(),
    state: Joi.string().optional(),
    nonce: Joi.string().optional(),
    code_challenge: Joi.string().optional(),
    code_challenge_method: Joi.string().valid('S256').optional(),
  }),

  // OAuth callback
  authCallback: Joi.object({
    code: Joi.string().required(),
    state: Joi.string().required(),
    session_id: Joi.string().uuid().required(),
  }),

  // Token exchange
  tokenExchange: Joi.object({
    grant_type: Joi.string().valid('authorization_code', 'refresh_token').required(),
    code: Joi.string().when('grant_type', {
      is: 'authorization_code',
      then: Joi.required(),
      otherwise: Joi.forbidden(),
    }),
    refresh_token: Joi.string().when('grant_type', {
      is: 'refresh_token',
      then: Joi.required(),
      otherwise: Joi.forbidden(),
    }),
    redirect_uri: Joi.string().uri().optional(),
    code_verifier: Joi.string().optional(),
  }),

  // Token refresh
  refreshToken: Joi.object({
    refresh_token: Joi.string().required(),
  }),

  // Session ID
  sessionId: Joi.object({
    session_id: Joi.string().uuid().required(),
  }),
};