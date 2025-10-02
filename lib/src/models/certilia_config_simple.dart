import 'package:flutter/foundation.dart';

/// Simplified configuration for client-server architecture
/// This configuration is for Flutter clients that communicate with a backend proxy server
/// The backend server handles all OAuth flow and Certilia API communication
@immutable
class CertiliaConfigSimple {
  /// Backend server URL that handles OAuth flow
  final String serverUrl;

  /// OAuth scopes to request (optional - server can override)
  final List<String> scopes;

  /// Whether to prefer ephemeral session on iOS
  final bool preferEphemeralSession;

  /// Enable debug logging
  final bool enableLogging;

  /// Session timeout in milliseconds (optional)
  final int? sessionTimeout;

  /// Creates a new [CertiliaConfigSimple]
  const CertiliaConfigSimple({
    required this.serverUrl,
    this.scopes = const ['openid', 'profile', 'eid'],
    this.preferEphemeralSession = true,
    this.enableLogging = false,
    this.sessionTimeout,
  });

  /// Validates the configuration
  void validate() {
    if (serverUrl.isEmpty) {
      throw ArgumentError('serverUrl cannot be empty');
    }
    if (!serverUrl.startsWith('http')) {
      throw ArgumentError('serverUrl must be a valid HTTP(S) URL');
    }
    if (scopes.isEmpty) {
      throw ArgumentError('scopes cannot be empty');
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CertiliaConfigSimple &&
          runtimeType == other.runtimeType &&
          serverUrl == other.serverUrl &&
          listEquals(scopes, other.scopes) &&
          preferEphemeralSession == other.preferEphemeralSession &&
          enableLogging == other.enableLogging &&
          sessionTimeout == other.sessionTimeout;

  @override
  int get hashCode =>
      serverUrl.hashCode ^
      scopes.hashCode ^
      preferEphemeralSession.hashCode ^
      enableLogging.hashCode ^
      sessionTimeout.hashCode;

  @override
  String toString() {
    return 'CertiliaConfigSimple('
        'serverUrl: $serverUrl, '
        'scopes: $scopes, '
        'preferEphemeralSession: $preferEphemeralSession, '
        'enableLogging: $enableLogging, '
        'sessionTimeout: $sessionTimeout)';
  }
}