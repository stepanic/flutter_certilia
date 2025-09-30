import 'package:flutter/foundation.dart';

/// Simplified configuration for Certilia OAuth client
/// This configuration is for Flutter clients that communicate with a backend proxy
@immutable
class CertiliaConfigSimple {
  /// OAuth client ID
  final String clientId;

  /// Backend server URL that handles OAuth flow
  final String serverUrl;

  /// OAuth redirect URL (usually your server's callback endpoint)
  final String redirectUrl;

  /// OAuth scopes to request
  final List<String> scopes;

  /// Whether to prefer ephemeral session on iOS
  final bool preferEphemeralSession;

  /// Enable debug logging
  final bool enableLogging;

  /// Session timeout in milliseconds (optional)
  final int? sessionTimeout;

  /// Creates a new [CertiliaConfigSimple]
  const CertiliaConfigSimple({
    required this.clientId,
    required this.serverUrl,
    required this.redirectUrl,
    this.scopes = const ['openid', 'profile', 'eid'],
    this.preferEphemeralSession = true,
    this.enableLogging = false,
    this.sessionTimeout,
  });

  /// Validates the configuration
  void validate() {
    if (clientId.isEmpty) {
      throw ArgumentError('clientId cannot be empty');
    }
    if (serverUrl.isEmpty) {
      throw ArgumentError('serverUrl cannot be empty');
    }
    if (redirectUrl.isEmpty) {
      throw ArgumentError('redirectUrl cannot be empty');
    }
    if (!serverUrl.startsWith('http')) {
      throw ArgumentError('serverUrl must be a valid HTTP(S) URL');
    }
    if (!redirectUrl.contains('://')) {
      throw ArgumentError('redirectUrl must be a valid URL');
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
          clientId == other.clientId &&
          serverUrl == other.serverUrl &&
          redirectUrl == other.redirectUrl &&
          listEquals(scopes, other.scopes) &&
          preferEphemeralSession == other.preferEphemeralSession &&
          enableLogging == other.enableLogging &&
          sessionTimeout == other.sessionTimeout;

  @override
  int get hashCode =>
      clientId.hashCode ^
      serverUrl.hashCode ^
      redirectUrl.hashCode ^
      scopes.hashCode ^
      preferEphemeralSession.hashCode ^
      enableLogging.hashCode ^
      sessionTimeout.hashCode;

  @override
  String toString() {
    return 'CertiliaConfigSimple('
        'clientId: $clientId, '
        'serverUrl: $serverUrl, '
        'redirectUrl: $redirectUrl, '
        'scopes: $scopes, '
        'preferEphemeralSession: $preferEphemeralSession, '
        'enableLogging: $enableLogging, '
        'sessionTimeout: $sessionTimeout)';
  }
}