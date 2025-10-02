import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/certilia_token.dart';

/// Service for managing token storage across all client implementations
/// Eliminates duplicate token storage logic from individual clients
class TokenStorageService {
  /// Storage key for tokens
  static const String _tokenStorageKey = 'certilia_token';

  /// Secure storage instance
  final FlutterSecureStorage _storage;

  /// Creates a new token storage service
  TokenStorageService({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  /// Saves token to secure storage
  Future<void> saveToken(CertiliaToken token) async {
    try {
      final tokenJson = jsonEncode(token.toJson());
      await _storage.write(key: _tokenStorageKey, value: tokenJson);
    } catch (e) {
      // Log but don't throw - let the caller decide how to handle
      print('[TokenStorageService] Failed to save token: $e');
    }
  }

  /// Loads token from secure storage
  Future<CertiliaToken?> loadToken() async {
    try {
      final tokenJson = await _storage.read(key: _tokenStorageKey);
      if (tokenJson != null) {
        final tokenData = jsonDecode(tokenJson) as Map<String, dynamic>;
        return CertiliaToken.fromJson(tokenData);
      }
    } catch (e) {
      // Log but don't throw - return null for missing/corrupted token
      print('[TokenStorageService] Failed to load token: $e');
    }
    return null;
  }

  /// Deletes token from storage
  Future<void> deleteToken() async {
    try {
      await _storage.delete(key: _tokenStorageKey);
    } catch (e) {
      // Log but don't throw
      print('[TokenStorageService] Failed to delete token: $e');
    }
  }

  /// Checks if a valid token exists
  Future<bool> hasValidToken() async {
    final token = await loadToken();
    return token != null && !token.isExpired;
  }
}