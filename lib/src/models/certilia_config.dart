import 'package:flutter/foundation.dart';

/// Configuration for the Flutter Certilia SDK.
///
/// The SDK uses a proxy-server architecture: the Flutter client talks only
/// to your backend (the `certilia-server`), which mediates all OAuth
/// communication with Certilia. The only required value here is the URL of
/// that proxy.
@immutable
class CertiliaConfig {
  /// Backend proxy server URL.
  final String serverUrl;

  /// OAuth scopes the proxy should request. The proxy server is free to
  /// override or extend this list.
  final List<String> scopes;

  /// Prefer iOS ephemeral session (no shared cookies) where supported.
  final bool preferEphemeralSession;

  /// Enable verbose SDK logging.
  final bool enableLogging;

  /// Session timeout in milliseconds. Currently informational only — wiring
  /// to live enforcement is tracked as a Phase 2 task.
  final int? sessionTimeout;

  const CertiliaConfig({
    required this.serverUrl,
    this.scopes = const ['openid', 'profile', 'eid'],
    this.preferEphemeralSession = true,
    this.enableLogging = false,
    this.sessionTimeout,
  });

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
      other is CertiliaConfig &&
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
    return 'CertiliaConfig('
        'serverUrl: $serverUrl, '
        'scopes: $scopes, '
        'preferEphemeralSession: $preferEphemeralSession, '
        'enableLogging: $enableLogging, '
        'sessionTimeout: $sessionTimeout)';
  }
}

/// Backward-compatible alias for the previous name.
@Deprecated('Use CertiliaConfig instead. Will be removed in 1.0.0.')
typedef CertiliaConfigSimple = CertiliaConfig;
