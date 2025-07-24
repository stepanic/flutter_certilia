import 'package:flutter/foundation.dart';

/// Represents OAuth token data
@immutable
class CertiliaToken {
  /// OAuth access token
  final String accessToken;

  /// OAuth refresh token (optional)
  final String? refreshToken;

  /// OAuth ID token (optional)
  final String? idToken;

  /// Token expiration time
  final DateTime? expiresAt;

  /// Token type (usually "Bearer")
  final String tokenType;

  /// Creates a new [CertiliaToken]
  const CertiliaToken({
    required this.accessToken,
    this.refreshToken,
    this.idToken,
    this.expiresAt,
    this.tokenType = 'Bearer',
  });

  /// Creates a [CertiliaToken] from a JSON map
  factory CertiliaToken.fromJson(Map<String, dynamic> json) {
    DateTime? expiresAt;
    
    // Handle expires_in field
    if (json['expires_in'] != null) {
      final expiresIn = json['expires_in'] as int;
      expiresAt = DateTime.now().add(Duration(seconds: expiresIn));
    }
    
    // Handle expires_at field (unix timestamp)
    if (json['expires_at'] != null) {
      final expiresAtTimestamp = json['expires_at'] as int;
      expiresAt = DateTime.fromMillisecondsSinceEpoch(expiresAtTimestamp * 1000);
    }

    return CertiliaToken(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String?,
      idToken: json['id_token'] as String?,
      expiresAt: expiresAt,
      tokenType: json['token_type'] as String? ?? 'Bearer',
    );
  }

  /// Converts this token to a JSON map
  Map<String, dynamic> toJson() {
    return {
      'access_token': accessToken,
      if (refreshToken != null) 'refresh_token': refreshToken,
      if (idToken != null) 'id_token': idToken,
      if (expiresAt != null)
        'expires_at': expiresAt!.millisecondsSinceEpoch ~/ 1000,
      'token_type': tokenType,
    };
  }

  /// Checks if the token is expired
  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  /// Gets the remaining time until expiration
  Duration? get timeUntilExpiry {
    if (expiresAt == null) return null;
    final remaining = expiresAt!.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// Creates a copy of this token with the given fields replaced
  CertiliaToken copyWith({
    String? accessToken,
    String? refreshToken,
    String? idToken,
    DateTime? expiresAt,
    String? tokenType,
  }) {
    return CertiliaToken(
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      idToken: idToken ?? this.idToken,
      expiresAt: expiresAt ?? this.expiresAt,
      tokenType: tokenType ?? this.tokenType,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CertiliaToken &&
          runtimeType == other.runtimeType &&
          accessToken == other.accessToken &&
          refreshToken == other.refreshToken &&
          idToken == other.idToken &&
          expiresAt == other.expiresAt &&
          tokenType == other.tokenType;

  @override
  int get hashCode =>
      accessToken.hashCode ^
      refreshToken.hashCode ^
      idToken.hashCode ^
      expiresAt.hashCode ^
      tokenType.hashCode;

  @override
  String toString() {
    return 'CertiliaToken('
        'accessToken: ${accessToken.substring(0, 10)}..., '
        'refreshToken: ${refreshToken != null ? '${refreshToken!.substring(0, 10)}...' : 'null'}, '
        'idToken: ${idToken != null ? '${idToken!.substring(0, 10)}...' : 'null'}, '
        'expiresAt: $expiresAt, '
        'tokenType: $tokenType)';
  }
}