// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
// ignore: deprecated_member_use
import 'dart:html' as html;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'constants.dart';
import 'exceptions/certilia_exception.dart';
import 'models/certilia_config.dart';
import 'models/certilia_token.dart';
import 'models/certilia_user.dart';

/// Web-specific client for Certilia OAuth authentication
/// Uses popup window for authentication on web platform
class CertiliaWebClient {
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

  /// Creates a new [CertiliaWebClient]
  CertiliaWebClient({
    required this.config,
    this.serverUrl,
    FlutterSecureStorage? secureStorage,
    http.Client? httpClient,
  })  : _secureStorage = secureStorage ?? const FlutterSecureStorage(),
        _httpClient = httpClient ?? http.Client() {
    config.validate();
  }

  /// Authenticates the user using popup window and returns their profile
  Future<CertiliaUser> authenticate(BuildContext context) async {
    try {
      _log('Starting web authentication flow');

      // Initialize OAuth flow
      final authData = await _initializeOAuthFlow();
      
      // Open popup for authentication
      final code = await _openAuthPopup(
        authData['authorization_url'],
        authData['state'],
      );

      if (code == null) {
        throw const CertiliaAuthenticationException(
          message: 'Authentication was cancelled',
        );
      }

      // Exchange code for tokens
      final tokenData = await _exchangeCodeForTokens(
        code: code,
        state: authData['state'],
        sessionId: authData['session_id'],
      );

      // Create token object
      _currentToken = CertiliaToken(
        accessToken: tokenData['accessToken'],
        refreshToken: tokenData['refreshToken'],
        idToken: tokenData['idToken'],
        expiresAt: tokenData['expiresIn'] != null
            ? DateTime.now().add(Duration(seconds: tokenData['expiresIn']))
            : null,
        tokenType: tokenData['tokenType'] ?? CertiliaConstants.defaultTokenType,
      );

      // Save token
      await _saveToken(_currentToken!);

      // Extract user from token data or fetch separately
      final user = tokenData['user'] != null
          ? CertiliaUser.fromJson(tokenData['user'])
          : await _fetchUserInfo(_currentToken!.accessToken);

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

  /// Initialize OAuth flow with the server
  Future<Map<String, dynamic>> _initializeOAuthFlow() async {
    if (serverUrl == null) {
      throw const CertiliaException(
        message: 'Server URL is required for web authentication',
      );
    }

    final response = await _httpClient.get(
      Uri.parse('$serverUrl/api/auth/initialize?response_type=code&redirect_uri=$serverUrl/api/auth/callback'),
    );

    if (response.statusCode != 200) {
      throw CertiliaNetworkException(
        message: 'Failed to initialize OAuth flow',
        statusCode: response.statusCode,
        details: response.body,
      );
    }

    return jsonDecode(response.body);
  }

  /// Opens authentication popup and returns authorization code
  Future<String?> _openAuthPopup(String authorizationUrl, String expectedState) async {
    final completer = Completer<String?>();
    
    // Calculate popup dimensions
    final width = 500;
    final height = 700;
    final left = (html.window.screen!.width! - width) ~/ 2;
    final top = (html.window.screen!.height! - height) ~/ 2;
    
    _log('Opening authentication popup...');
    _log('Authorization URL: $authorizationUrl');
    
    // Open popup window
    final popup = html.window.open(
      authorizationUrl,
      'certilia_auth',
      'width=$width,height=$height,left=$left,top=$top',
    );
    
    // Check if popup was blocked
    // ignore: unnecessary_null_comparison
    if (popup == null) {
      throw const CertiliaAuthenticationException(
        message: 'Failed to open authentication popup. Please check popup blocker settings.',
      );
    }

    // Listen for messages from popup
    StreamSubscription? messageSubscription;
    Timer? checkTimer;
    
    void cleanup() {
      messageSubscription?.cancel();
      checkTimer?.cancel();
    }
    
    // Listen for postMessage from callback page
    messageSubscription = html.window.onMessage.listen((event) {
      try {
        _log('Received message from popup: ${event.data}');
        _log('Message origin: ${event.origin}');
        
        // Check if message is from our server
        if (serverUrl != null && !event.origin.startsWith(serverUrl)) {
          _log('Ignoring message from untrusted origin: ${event.origin}');
          return;
        }
        
        // Parse message data
        final data = event.data;
        if (data is String) {
          final parsed = jsonDecode(data);
          if (parsed['type'] == 'certilia_callback') {
            _log('Processing certilia_callback message');
            final code = parsed['code'];
            final state = parsed['state'];
            final error = parsed['error'];
            
            if (error != null && error != '') {
              _log('Authentication error: $error');
              cleanup();
              completer.complete(null);
              popup.close();
            } else if (code != null && code != '' && state == expectedState) {
              _log('Authentication successful, code received: $code');
              cleanup();
              completer.complete(code);
              popup.close();
            } else {
              _log('Invalid callback data - code: $code, state: $state (expected: $expectedState)');
            }
          }
        }
      } catch (e) {
        _log('Error processing message: $e');
      }
    });
    
    // Check if popup was closed
    checkTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (popup.closed ?? false) {
        cleanup();
        if (!completer.isCompleted) {
          completer.complete(null);
        }
      }
    });
    
    return completer.future;
  }

  /// Exchange authorization code for tokens
  Future<Map<String, dynamic>> _exchangeCodeForTokens({
    required String code,
    required String state,
    required String sessionId,
  }) async {
    if (serverUrl == null) {
      throw const CertiliaException(
        message: 'Server URL is required for token exchange',
      );
    }

    final response = await _httpClient.post(
      Uri.parse('$serverUrl/api/auth/exchange'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'code': code,
        'state': state,
        'session_id': sessionId,
      }),
    );

    if (response.statusCode != 200) {
      throw CertiliaNetworkException(
        message: 'Failed to exchange code for tokens',
        statusCode: response.statusCode,
        details: response.body,
      );
    }

    return jsonDecode(response.body);
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

    if (serverUrl == null) {
      throw const CertiliaException(
        message: 'Server URL is required for token refresh',
      );
    }

    try {
      _log('Refreshing token');

      final response = await _httpClient.post(
        Uri.parse('$serverUrl/api/auth/refresh'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${_currentToken!.refreshToken}',
        },
      );

      if (response.statusCode != 200) {
        throw CertiliaNetworkException(
          message: 'Token refresh failed',
          statusCode: response.statusCode,
          details: response.body,
        );
      }

      final tokenData = jsonDecode(response.body);

      // Update token
      _currentToken = CertiliaToken(
        accessToken: tokenData['accessToken'],
        refreshToken: tokenData['refreshToken'] ?? _currentToken!.refreshToken,
        idToken: tokenData['idToken'],
        expiresAt: tokenData['expiresIn'] != null
            ? DateTime.now().add(Duration(seconds: tokenData['expiresIn']))
            : null,
        tokenType: tokenData['tokenType'] ?? CertiliaConstants.defaultTokenType,
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

  /// Fetches user information from the server
  Future<CertiliaUser> _fetchUserInfo(String accessToken) async {
    if (serverUrl == null) {
      // Direct API call to Certilia
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
    } else {
      // Server middleware API call
      final response = await _httpClient.get(
        Uri.parse('$serverUrl/api/auth/user'),
        headers: {
          'Authorization': 'Bearer $accessToken',
        },
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return CertiliaUser.fromJson(json['user']);
      } else {
        throw CertiliaNetworkException(
          message: 'Failed to fetch user info',
          statusCode: response.statusCode,
          details: response.body,
        );
      }
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
      developer.log(message, name: 'CertiliaWebClient');
      if (kDebugMode) {
        debugPrint('[CertiliaWebClient] $message');
      }
    }
  }

  /// Disposes of resources
  void dispose() {
    _httpClient.close();
  }
}

/// Alias for platform client
typedef CertiliaPlatformClient = CertiliaWebClient;