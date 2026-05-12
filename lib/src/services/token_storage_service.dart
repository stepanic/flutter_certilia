import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/certilia_token.dart';

/// Service for managing token storage across all client implementations.
class TokenStorageService {
  static const String _tokenStorageKey = 'certilia_token';

  final FlutterSecureStorage _storage;

  TokenStorageService({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  Future<void> saveToken(CertiliaToken token) async {
    try {
      final tokenJson = jsonEncode(token.toJson());
      await _storage.write(key: _tokenStorageKey, value: tokenJson);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[TokenStorageService] Failed to save token: $e');
      }
    }
  }

  Future<CertiliaToken?> loadToken() async {
    try {
      final tokenJson = await _storage.read(key: _tokenStorageKey);
      if (tokenJson != null) {
        final tokenData = jsonDecode(tokenJson) as Map<String, dynamic>;
        return CertiliaToken.fromJson(tokenData);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[TokenStorageService] Failed to load token: $e');
      }
    }
    return null;
  }

  Future<void> deleteToken() async {
    try {
      await _storage.delete(key: _tokenStorageKey);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[TokenStorageService] Failed to delete token: $e');
      }
    }
  }

  Future<bool> hasValidToken() async {
    final token = await loadToken();
    return token != null && !token.isExpired;
  }
}
