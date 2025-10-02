import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

/// Centralized logging service for Certilia SDK
/// Eliminates duplicate logging logic from individual clients
class CertiliaLogger {
  /// Whether logging is enabled
  final bool enableLogging;

  /// The name of the component doing the logging
  final String componentName;

  /// Creates a new logger instance
  CertiliaLogger({
    required this.componentName,
    this.enableLogging = false,
  });

  /// Logs a message if logging is enabled
  void log(String message) {
    if (enableLogging) {
      developer.log(message, name: componentName);
      if (kDebugMode) {
        debugPrint('[$componentName] $message');
      }
    }
  }

  /// Logs an error message (always logs in debug mode)
  void error(String message, [Object? error, StackTrace? stackTrace]) {
    if (enableLogging || kDebugMode) {
      developer.log(
        message,
        name: componentName,
        error: error,
        stackTrace: stackTrace,
        level: 1000, // Error level
      );
      if (kDebugMode) {
        debugPrint('[$componentName] ERROR: $message');
        if (error != null) {
          debugPrint('[$componentName] Error details: $error');
        }
      }
    }
  }

  /// Logs a warning message
  void warning(String message) {
    if (enableLogging) {
      developer.log(
        message,
        name: componentName,
        level: 900, // Warning level
      );
      if (kDebugMode) {
        debugPrint('[$componentName] WARNING: $message');
      }
    }
  }

  /// Logs an info message
  void info(String message) {
    if (enableLogging) {
      developer.log(
        message,
        name: componentName,
        level: 800, // Info level
      );
      if (kDebugMode) {
        debugPrint('[$componentName] INFO: $message');
      }
    }
  }

  /// Logs a debug message (only in debug mode)
  void debug(String message) {
    if (enableLogging && kDebugMode) {
      developer.log(
        message,
        name: componentName,
        level: 500, // Debug level
      );
      debugPrint('[$componentName] DEBUG: $message');
    }
  }
}