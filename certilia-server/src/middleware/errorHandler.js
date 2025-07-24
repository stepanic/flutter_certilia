import logger from '../utils/logger.js';
import { AppError } from '../utils/errors.js';

/**
 * Global error handler middleware
 */
export const errorHandler = (err, req, res, next) => {
  // Default to 500 server error
  let statusCode = err.statusCode || 500;
  let message = err.message || 'Internal Server Error';
  let code = err.code || 'INTERNAL_ERROR';

  // Log error
  if (statusCode >= 500) {
    logger.error('Server Error', {
      error: {
        message: err.message,
        stack: err.stack,
        code: err.code,
      },
      request: {
        method: req.method,
        url: req.url,
        headers: req.headers,
        body: req.body,
      },
    });
  } else {
    logger.warn('Client Error', {
      error: {
        message: err.message,
        code: err.code,
      },
      request: {
        method: req.method,
        url: req.url,
      },
    });
  }

  // Handle specific error types
  if (err.name === 'ValidationError') {
    statusCode = 400;
    message = 'Validation Error';
    code = 'VALIDATION_ERROR';
  } else if (err.name === 'CastError') {
    statusCode = 400;
    message = 'Invalid ID format';
    code = 'INVALID_ID';
  }

  // Don't expose internal error details in production
  if (process.env.NODE_ENV === 'production' && statusCode === 500) {
    message = 'Internal Server Error';
  }

  // Send error response
  res.status(statusCode).json({
    error: {
      code,
      message,
      ...(err.errors && { details: err.errors }),
      ...(process.env.NODE_ENV === 'development' && {
        stack: err.stack,
      }),
    },
    timestamp: new Date().toISOString(),
  });
};

/**
 * 404 handler
 */
export const notFoundHandler = (req, res, next) => {
  res.status(404).json({
    error: {
      code: 'NOT_FOUND',
      message: 'Resource not found',
    },
    timestamp: new Date().toISOString(),
  });
};