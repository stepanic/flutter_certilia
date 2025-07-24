/// Base exception class for all Certilia-related errors
class CertiliaException implements Exception {
  /// Error message
  final String message;

  /// Error code if available
  final String? code;

  /// Additional details about the error
  final dynamic details;

  /// Creates a new [CertiliaException]
  const CertiliaException({
    required this.message,
    this.code,
    this.details,
  });

  @override
  String toString() {
    final buffer = StringBuffer('CertiliaException: $message');
    if (code != null) {
      buffer.write(' (Code: $code)');
    }
    if (details != null) {
      buffer.write('\nDetails: $details');
    }
    return buffer.toString();
  }
}

/// Exception thrown when authentication fails
class CertiliaAuthenticationException extends CertiliaException {
  /// Creates a new [CertiliaAuthenticationException]
  const CertiliaAuthenticationException({
    required super.message,
    super.code,
    super.details,
  });
}

/// Exception thrown when network operations fail
class CertiliaNetworkException extends CertiliaException {
  /// HTTP status code if available
  final int? statusCode;

  /// Creates a new [CertiliaNetworkException]
  const CertiliaNetworkException({
    required super.message,
    this.statusCode,
    super.code,
    super.details,
  });

  @override
  String toString() {
    final buffer = StringBuffer('CertiliaNetworkException: $message');
    if (statusCode != null) {
      buffer.write(' (HTTP $statusCode)');
    }
    if (code != null) {
      buffer.write(' (Code: $code)');
    }
    if (details != null) {
      buffer.write('\nDetails: $details');
    }
    return buffer.toString();
  }
}

/// Exception thrown when configuration is invalid
class CertiliaConfigurationException extends CertiliaException {
  /// Creates a new [CertiliaConfigurationException]
  const CertiliaConfigurationException({
    required super.message,
    super.code,
    super.details,
  });
}