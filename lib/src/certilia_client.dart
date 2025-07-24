import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'constants.dart';
import 'exceptions/certilia_exception.dart';
import 'models/certilia_config.dart';
import 'models/certilia_token.dart';
import 'models/certilia_user.dart';

/// Main client for Certilia OAuth authentication
class CertiliaClient {
  /// Configuration for the client
  final CertiliaConfig config;

  /// AppAuth instance for OAuth operations
  final FlutterAppAuth _appAuth;

  /// Secure storage for tokens
  final FlutterSecureStorage _secureStorage;

  /// HTTP client for API requests
  final http.Client _httpClient;

  /// Current authentication token
  CertiliaToken? _currentToken;

  /// Storage key for tokens
  static const String _tokenStorageKey = 'certilia_token';

  /// Creates a new [CertiliaClient]
  CertiliaClient({
    required this.config,
    FlutterAppAuth? appAuth,
    FlutterSecureStorage? secureStorage,
    http.Client? httpClient,
  })  : _appAuth = appAuth ?? const FlutterAppAuth(),
        _secureStorage = secureStorage ?? const FlutterSecureStorage(),
        _httpClient = httpClient ?? http.Client() {
    config.validate();
  }

  /// Authenticates the user and returns their profile
  Future<CertiliaUser> authenticate() async {
    try {
      _log('Starting authentication flow');
      
      // Perform OAuth authentication
      final result = await _appAuth.authorizeAndExchangeCode(
        AuthorizationTokenRequest(
          config.clientId,
          config.redirectUrl,
          discoveryUrl: config.discoveryUrl,
          serviceConfiguration: config.discoveryUrl == null
              ? const AuthorizationServiceConfiguration(
                  authorizationEndpoint: CertiliaConstants.authorizationEndpoint,
                  tokenEndpoint: CertiliaConstants.tokenEndpoint,
                )
              : null,
          scopes: config.scopes,
          preferEphemeralSession: config.preferEphemeralSession,
          additionalParameters: {
            'prompt': 'login',
          },
        ),
      );

      if (result == null) {
        throw const CertiliaAuthenticationException(
          message: 'Authentication was cancelled or failed',
        );
      }
      
      final accessToken = result.accessToken;
      if (accessToken == null) {
        throw const CertiliaAuthenticationException(
          message: 'No access token received',
        );
      }

      // Create token object
      _currentToken = CertiliaToken(
        accessToken: accessToken,
        refreshToken: result.refreshToken,
        idToken: result.idToken,
        expiresAt: result.accessTokenExpirationDateTime,
        tokenType: result.tokenType ?? CertiliaConstants.defaultTokenType,
      );

      // Save token
      await _saveToken(_currentToken!);

      // Fetch user info
      final user = await _fetchUserInfo(_currentToken!.accessToken);
      
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

  /// Checks if the user is currently authenticated
  bool get isAuthenticated {
    return _currentToken != null && !_currentToken!.isExpired;
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

      // Fetch user info
      return await _fetchUserInfo(_currentToken!.accessToken);
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
      
      final result = await _appAuth.token(
        TokenRequest(
          config.clientId,
          config.redirectUrl,
          discoveryUrl: config.discoveryUrl,
          serviceConfiguration: config.discoveryUrl == null
              ? const AuthorizationServiceConfiguration(
                  authorizationEndpoint: CertiliaConstants.authorizationEndpoint,
                  tokenEndpoint: CertiliaConstants.tokenEndpoint,
                )
              : null,
          refreshToken: _currentToken!.refreshToken,
          grantType: 'refresh_token',
        ),
      );

      if (result == null) {
        throw const CertiliaAuthenticationException(
          message: 'Token refresh failed',
        );
      }
      
      final accessToken = result.accessToken;
      if (accessToken == null) {
        throw const CertiliaAuthenticationException(
          message: 'No access token received during refresh',
        );
      }

      // Update token
      _currentToken = CertiliaToken(
        accessToken: accessToken,
        refreshToken: result.refreshToken ?? _currentToken!.refreshToken,
        idToken: result.idToken,
        expiresAt: result.accessTokenExpirationDateTime,
        tokenType: result.tokenType ?? CertiliaConstants.defaultTokenType,
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

  /// Ends the OAuth session (performs logout at the authorization server)
  Future<void> endSession() async {
    try {
      _log('Ending OAuth session');
      
      if (_currentToken?.idToken == null) {
        throw const CertiliaAuthenticationException(
          message: 'No ID token available for ending session',
        );
      }

      await _appAuth.endSession(
        EndSessionRequest(
          idTokenHint: _currentToken!.idToken,
          postLogoutRedirectUrl: config.redirectUrl,
          discoveryUrl: config.discoveryUrl,
          serviceConfiguration: config.discoveryUrl == null
              ? const AuthorizationServiceConfiguration(
                  authorizationEndpoint: CertiliaConstants.authorizationEndpoint,
                  tokenEndpoint: CertiliaConstants.tokenEndpoint,
                )
              : null,
        ),
      );

      // Clear local session
      await logout();
      
      _log('Session ended successfully');
    } catch (e) {
      _log('Failed to end session: $e');
      if (e is CertiliaException) {
        rethrow;
      }
      throw CertiliaException(
        message: 'Failed to end session',
        details: e.toString(),
      );
    }
  }

  /// Fetches user information from the userinfo endpoint
  Future<CertiliaUser> _fetchUserInfo(String accessToken) async {
    try {
      final response = await _httpClient.get(
        Uri.parse(CertiliaConstants.userInfoEndpoint),
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
    } catch (e) {
      if (e is CertiliaException) {
        rethrow;
      }
      throw CertiliaNetworkException(
        message: 'Network error while fetching user info',
        details: e.toString(),
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

  /// Logs a message if logging is enabled
  void _log(String message) {
    if (config.enableLogging) {
      developer.log(message, name: 'CertiliaClient');
      if (kDebugMode) {
        debugPrint('[CertiliaClient] $message');
      }
    }
  }

  /// Disposes of resources
  void dispose() {
    _httpClient.close();
  }
}