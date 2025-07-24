import 'package:flutter/foundation.dart';
import '../constants.dart';

/// Configuration for Certilia OAuth client
@immutable
class CertiliaConfig {
  /// OAuth client ID
  final String clientId;

  /// OAuth redirect URL
  final String redirectUrl;

  /// OAuth scopes to request
  final List<String> scopes;

  /// Discovery URL for auto-configuration (optional)
  final String? discoveryUrl;

  /// Whether to prefer ephemeral session on iOS
  final bool preferEphemeralSession;

  /// Enable debug logging
  final bool enableLogging;

  /// Custom user agent string (optional)
  final String? customUserAgent;

  /// Creates a new [CertiliaConfig]
  const CertiliaConfig({
    required this.clientId,
    required this.redirectUrl,
    this.scopes = CertiliaConstants.defaultScopes,
    this.discoveryUrl,
    this.preferEphemeralSession = true,
    this.enableLogging = false,
    this.customUserAgent,
  });

  /// Creates a copy of this config with the given fields replaced
  CertiliaConfig copyWith({
    String? clientId,
    String? redirectUrl,
    List<String>? scopes,
    String? discoveryUrl,
    bool? preferEphemeralSession,
    bool? enableLogging,
    String? customUserAgent,
  }) {
    return CertiliaConfig(
      clientId: clientId ?? this.clientId,
      redirectUrl: redirectUrl ?? this.redirectUrl,
      scopes: scopes ?? this.scopes,
      discoveryUrl: discoveryUrl ?? this.discoveryUrl,
      preferEphemeralSession: preferEphemeralSession ?? this.preferEphemeralSession,
      enableLogging: enableLogging ?? this.enableLogging,
      customUserAgent: customUserAgent ?? this.customUserAgent,
    );
  }

  /// Validates the configuration
  void validate() {
    if (clientId.isEmpty) {
      throw ArgumentError('clientId cannot be empty');
    }
    if (redirectUrl.isEmpty) {
      throw ArgumentError('redirectUrl cannot be empty');
    }
    if (scopes.isEmpty) {
      throw ArgumentError('scopes cannot be empty');
    }
    if (!redirectUrl.contains('://')) {
      throw ArgumentError('redirectUrl must be a valid URL');
    }
  }

  /// Gets the effective user agent string
  String get userAgent => customUserAgent ?? CertiliaConstants.userAgent;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CertiliaConfig &&
          runtimeType == other.runtimeType &&
          clientId == other.clientId &&
          redirectUrl == other.redirectUrl &&
          listEquals(scopes, other.scopes) &&
          discoveryUrl == other.discoveryUrl &&
          preferEphemeralSession == other.preferEphemeralSession &&
          enableLogging == other.enableLogging &&
          customUserAgent == other.customUserAgent;

  @override
  int get hashCode =>
      clientId.hashCode ^
      redirectUrl.hashCode ^
      scopes.hashCode ^
      discoveryUrl.hashCode ^
      preferEphemeralSession.hashCode ^
      enableLogging.hashCode ^
      customUserAgent.hashCode;

  @override
  String toString() {
    return 'CertiliaConfig('
        'clientId: $clientId, '
        'redirectUrl: $redirectUrl, '
        'scopes: $scopes, '
        'discoveryUrl: $discoveryUrl, '
        'preferEphemeralSession: $preferEphemeralSession, '
        'enableLogging: $enableLogging, '
        'customUserAgent: $customUserAgent)';
  }
}