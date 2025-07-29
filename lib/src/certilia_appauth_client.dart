import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'exceptions/certilia_exception.dart';
import 'models/certilia_config.dart';
import 'models/certilia_extended_info.dart';
import 'models/certilia_token.dart';
import 'models/certilia_user.dart';

/// AppAuth-based client for Certilia OAuth authentication
/// This client uses native browser for secure authentication
class CertiliaAppAuthClient {
  /// Configuration for the client
  final CertiliaConfig config;

  /// Secure storage for tokens
  final FlutterSecureStorage _secureStorage;

  /// HTTP client for API requests
  final http.Client _httpClient;

  /// Server base URL (if using middleware server)
  final String? serverUrl;

  /// Current authentication token
  CertiliaToken? _currentToken;

  /// Storage key for tokens
  static const String _tokenStorageKey = 'certilia_token';

  /// AppAuth instance
  final FlutterAppAuth _appAuth;

  /// Creates a new [CertiliaAppAuthClient]
  CertiliaAppAuthClient({
    required this.config,
    this.serverUrl,
    FlutterSecureStorage? secureStorage,
    http.Client? httpClient,
    FlutterAppAuth? appAuth,
  })  : _secureStorage = secureStorage ?? const FlutterSecureStorage(),
        _httpClient = httpClient ?? http.Client(),
        _appAuth = appAuth ?? const FlutterAppAuth() {
    config.validate();
    // Load saved tokens on initialization
    _initializeTokens();
  }

  /// Initialize tokens from storage
  Future<void> _initializeTokens() async {
    try {
      await _loadToken();
      if (_currentToken != null && !_currentToken!.isExpired) {
        _log('Loaded saved authentication token');
      } else if (_currentToken != null && _currentToken!.isExpired) {
        _log('Saved token is expired');
        // Don't automatically refresh here - let the app decide
      }
    } catch (e) {
      _log('Failed to load saved tokens: $e');
    }
  }

  /// Authenticates the user using native browser and returns their profile
  Future<CertiliaUser> authenticate(BuildContext context) async {
    try {
      _log('Starting AppAuth authentication flow');
      _log('Client ID: ${config.clientId}');
      _log('Redirect URL: ${config.redirectUrl}');
      _log('Scopes: ${config.scopes.join(', ')}');

      // Build OAuth endpoints - for AppAuth we need to use direct Certilia endpoints
      // We'll use manual endpoints instead of discovery since Certilia's discovery might not be standard
      final authorizationEndpoint = config.authorizationEndpoint;
      final tokenEndpoint = config.tokenEndpoint;
      
      _log('Authorization endpoint: $authorizationEndpoint');
      _log('Token endpoint: $tokenEndpoint');

      // Perform authorization request with manual endpoints
      _log('Creating authorization request...');
      final result = await _appAuth.authorizeAndExchangeCode(
        AuthorizationTokenRequest(
          config.clientId,
          config.redirectUrl,
          serviceConfiguration: AuthorizationServiceConfiguration(
            authorizationEndpoint: authorizationEndpoint,
            tokenEndpoint: tokenEndpoint,
          ),
          scopes: config.scopes,
          promptValues: ['login'], // Force login screen - use promptValues instead of additionalParameters
          preferEphemeralSession: true, // Don't share session with browser
          allowInsecureConnections: false, // Force HTTPS
        ),
      );

      _log('Authentication response received');
      _log('Got access token: ${result.accessToken != null}');
      _log('Got refresh token: ${result.refreshToken != null}');
      _log('Got ID token: ${result.idToken != null}');

      // Create token object
      _currentToken = CertiliaToken(
        accessToken: result.accessToken!,
        refreshToken: result.refreshToken,
        idToken: result.idToken,
        expiresAt: result.accessTokenExpirationDateTime,
        tokenType: result.tokenType ?? 'Bearer',
      );

      // Save token
      await _saveToken(_currentToken!);

      // Extract user from ID token or fetch separately
      CertiliaUser user;
      if (result.idToken != null) {
        user = _extractUserFromIdToken(result.idToken!);
      } else {
        user = await _fetchUserInfo(_currentToken!.accessToken);
      }

      _log('Authentication successful for user: ${user.sub}');
      return user;
    } catch (e) {
      _log('Authentication failed: $e');
      if (e is CertiliaException) {
        rethrow;
      }
      throw CertiliaAuthenticationException(
        message: 'Authentication failed',
        details: e.toString(),
      );
    }
  }

  /// Extract user information from ID token
  CertiliaUser _extractUserFromIdToken(String idToken) {
    try {
      // Decode JWT without verification (AppAuth already verified it)
      final parts = idToken.split('.');
      if (parts.length != 3) {
        throw const FormatException('Invalid ID token format');
      }

      final payload = parts[1];
      final normalizedPayload = base64.normalize(payload);
      final payloadData = utf8.decode(base64.decode(normalizedPayload));
      final claims = jsonDecode(payloadData) as Map<String, dynamic>;

      return CertiliaUser(
        sub: claims['sub'] as String,
        firstName: claims['given_name'] as String?,
        lastName: claims['family_name'] as String?,
        oib: claims['oib'] as String?,
        email: claims['email'] as String?,
        dateOfBirth: claims['birthdate'] != null
            ? DateTime.tryParse(claims['birthdate'] as String)
            : null,
        raw: claims,
      );
    } catch (e) {
      _log('Failed to extract user from ID token: $e');
      throw CertiliaException(
        message: 'Failed to parse ID token',
        details: e.toString(),
      );
    }
  }

  /// Checks if the user is currently authenticated
  bool get isAuthenticated {
    return _currentToken != null && !_currentToken!.isExpired;
  }

  /// Checks authentication status including loading from storage
  Future<bool> checkAuthenticationStatus() async {
    if (_currentToken == null) {
      await _loadToken();
    }
    return isAuthenticated;
  }

  /// Gets the current authenticated user
  Future<CertiliaUser?> getCurrentUser() async {
    try {
      // Load token if not in memory
      if (_currentToken == null) {
        await _loadToken();
      }

      if (_currentToken == null) {
        return null;
      }

      // Check if token is expired
      if (_currentToken!.isExpired) {
        // Try to refresh
        if (_currentToken!.refreshToken != null) {
          await refreshToken();
        } else {
          return null;
        }
      }

      // Extract user from ID token or fetch from API
      if (_currentToken!.idToken != null) {
        return _extractUserFromIdToken(_currentToken!.idToken!);
      } else {
        return await _fetchUserInfo(_currentToken!.accessToken);
      }
    } catch (e) {
      _log('Failed to get current user: $e');
      return null;
    }
  }

  /// Refreshes the access token using the refresh token
  Future<void> refreshToken() async {
    if (_currentToken?.refreshToken == null) {
      throw const CertiliaAuthenticationException(
        message: 'No refresh token available',
      );
    }

    try {
      _log('Refreshing token');

      // Use manual endpoints for token refresh
      final tokenEndpoint = config.tokenEndpoint;

      final result = await _appAuth.token(
        TokenRequest(
          config.clientId,
          config.redirectUrl,
          serviceConfiguration: AuthorizationServiceConfiguration(
            authorizationEndpoint: config.authorizationEndpoint,
            tokenEndpoint: tokenEndpoint,
          ),
          refreshToken: _currentToken!.refreshToken,
          scopes: config.scopes,
        ),
      );

      // Update token
      _currentToken = CertiliaToken(
        accessToken: result.accessToken!,
        refreshToken: result.refreshToken ?? _currentToken!.refreshToken,
        idToken: result.idToken,
        expiresAt: result.accessTokenExpirationDateTime,
        tokenType: result.tokenType ?? 'Bearer',
      );

      // Save updated token
      await _saveToken(_currentToken!);

      _log('Token refreshed successfully');
    } catch (e) {
      _log('Token refresh failed: $e');
      if (e is CertiliaException) {
        rethrow;
      }
      throw CertiliaAuthenticationException(
        message: 'Failed to refresh token',
        details: e.toString(),
      );
    }
  }

  /// Logs out the user and clears stored tokens
  Future<void> logout() async {
    try {
      _log('Logging out user');

      // End session if ID token is available
      if (_currentToken?.idToken != null) {
        try {
          // Note: Certilia might not support end session endpoint
          // For now, we'll just clear local tokens
          _log('End session endpoint not implemented, clearing local tokens only');
        } catch (e) {
          _log('End session failed: $e');
          // Continue with local logout even if end session fails
        }
      }

      // Clear token from memory
      _currentToken = null;

      // Clear token from storage
      await _secureStorage.delete(key: _tokenStorageKey);

      _log('Logout successful');
    } catch (e) {
      _log('Logout failed: $e');
      throw CertiliaException(
        message: 'Failed to logout',
        details: e.toString(),
      );
    }
  }

  /// Get extended user information
  Future<CertiliaExtendedInfo?> getExtendedUserInfo() async {
    try {
      // Check if we have a valid token
      if (_currentToken == null) {
        await _loadToken();
      }

      if (_currentToken == null || _currentToken!.isExpired) {
        _log('No valid token available for extended info');
        return null;
      }

      if (serverUrl == null) {
        _log('Server URL not provided - extended user info requires middleware server');
        // Return basic info from token if available
        if (_currentToken!.idToken != null) {
          try {
            final user = _extractUserFromIdToken(_currentToken!.idToken!);
            return CertiliaExtendedInfo.fromJson({
              'userInfo': user.raw,
              'availableFields': user.raw.keys.toList(),
              'raw': user.raw,
            });
          } catch (e) {
            _log('Failed to extract basic info from token: $e');
          }
        }
        return null;
      }

      _log('Fetching extended user info');

      final client = http.Client();
      try {
        final response = await client.get(
          Uri.parse('$serverUrl/api/user/extended-info'),
          headers: {
            'Authorization': 'Bearer ${_currentToken!.accessToken}',
            'ngrok-skip-browser-warning': 'true',
          },
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          _log('Extended user info fetched successfully');
          _log('Available fields: ${data['availableFields']}');
          return CertiliaExtendedInfo.fromJson(data);
        } else if (response.statusCode == 401 || response.statusCode == 502) {
          _log('Token expired or invalid (${response.statusCode})');

          // Check if error indicates expired token
          if (response.body.contains('Invalid or expired access token')) {
            _log('Token is definitely expired, clearing authentication');
            // Clear invalid tokens
            await logout();
            return null;
          }

          // Try to refresh if we have a refresh token
          if (_currentToken!.refreshToken != null) {
            try {
              await refreshToken();
              // Retry with new token
              return getExtendedUserInfo();
            } catch (refreshError) {
              _log('Refresh failed, clearing authentication: $refreshError');
              await logout();
              return null;
            }
          }
          return null;
        } else {
          _log('Failed to fetch extended user info: ${response.statusCode}');
          throw CertiliaNetworkException(
            message: 'Failed to fetch extended user info',
            statusCode: response.statusCode,
            details: response.body,
          );
        }
      } finally {
        client.close();
      }
    } catch (e) {
      _log('Error fetching extended user info: $e');
      if (e is CertiliaException) {
        rethrow;
      }
      throw CertiliaException(
        message: 'Failed to fetch extended user info',
        details: e.toString(),
      );
    }
  }

  /// Fetches user information from the server
  Future<CertiliaUser> _fetchUserInfo(String accessToken) async {
    // Always use direct Certilia endpoint for AppAuth
    final userInfoEndpoint = config.userInfoEndpoint;

    final response = await _httpClient.get(
      Uri.parse(userInfoEndpoint),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'User-Agent': config.userAgent,
      },
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return CertiliaUser.fromJson(json);
    } else {
      throw CertiliaNetworkException(
        message: 'Failed to fetch user info',
        statusCode: response.statusCode,
        details: response.body,
      );
    }
  }

  /// Saves token to secure storage
  Future<void> _saveToken(CertiliaToken token) async {
    try {
      final tokenJson = jsonEncode(token.toJson());
      await _secureStorage.write(key: _tokenStorageKey, value: tokenJson);
    } catch (e) {
      _log('Failed to save token: $e');
    }
  }

  /// Loads token from secure storage
  Future<void> _loadToken() async {
    try {
      final tokenJson = await _secureStorage.read(key: _tokenStorageKey);
      if (tokenJson != null) {
        final tokenData = jsonDecode(tokenJson) as Map<String, dynamic>;
        _currentToken = CertiliaToken.fromJson(tokenData);
      }
    } catch (e) {
      _log('Failed to load token: $e');
    }
  }

  /// Gets the current access token
  String? get currentAccessToken => _currentToken?.accessToken;

  /// Gets the current refresh token
  String? get currentRefreshToken => _currentToken?.refreshToken;

  /// Gets the current ID token
  String? get currentIdToken => _currentToken?.idToken;

  /// Gets the token expiry time
  DateTime? get tokenExpiry => _currentToken?.expiresAt;

  /// Logs a message if logging is enabled
  void _log(String message) {
    if (config.enableLogging) {
      developer.log(message, name: 'CertiliaAppAuthClient');
      if (kDebugMode) {
        debugPrint('[CertiliaAppAuthClient] $message');
      }
    }
  }

  /// Disposes of resources
  void dispose() {
    _httpClient.close();
  }
}

/// Alias for platform client
typedef CertiliaPlatformClient = CertiliaAppAuthClient;