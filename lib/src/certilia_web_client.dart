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

import 'exceptions/certilia_exception.dart';
import 'models/certilia_config.dart';
import 'models/certilia_token.dart';
import 'models/certilia_user.dart';
import 'models/certilia_extended_info.dart';

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

  /// Authenticates the user using popup window and returns their profile
  Future<CertiliaUser> authenticate(BuildContext context) async {
    try {
      _log('Starting web authentication flow');

      // Initialize OAuth flow
      final authData = await _initializeOAuthFlow();
      
      // Start polling session
      final pollingData = await _startPollingSession(
        state: authData['state'],
        sessionId: authData['session_id'],
      );
      
      // Open popup for authentication
      _log('Opening authentication popup with polling...');
      final code = await _openAuthPopupWithPolling(
        authData['authorization_url'],
        authData['state'],
        pollingData['polling_id'],
      );

      _log('Authentication flow completed, received code: ${code ?? "null"}');
      
      if (code == null) {
        _log('ERROR: No code received - authentication was cancelled or failed');
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
        tokenType: tokenData['tokenType'] ?? 'Bearer',
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

  /// Start polling session on server
  Future<Map<String, dynamic>> _startPollingSession({
    required String state,
    required String sessionId,
  }) async {
    if (serverUrl == null) {
      throw const CertiliaException(
        message: 'Server URL is required for polling authentication',
      );
    }

    _log('Starting polling session for state: $state');
    
    final response = await _httpClient.post(
      Uri.parse('$serverUrl/api/auth/polling/start'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'state': state,
        'session_id': sessionId,
      }),
    );

    if (response.statusCode != 200) {
      throw CertiliaNetworkException(
        message: 'Failed to start polling session',
        statusCode: response.statusCode,
        details: response.body,
      );
    }

    final data = jsonDecode(response.body);
    _log('Polling session created: ${data['polling_id']}');
    return data;
  }

  /// Open authentication popup with server polling
  Future<String?> _openAuthPopupWithPolling(
    String authorizationUrl,
    String expectedState,
    String pollingId,
  ) async {
    final completer = Completer<String?>();
    
    // Calculate popup dimensions
    final width = 500;
    final height = 700;
    final left = (html.window.screen!.width! - width) ~/ 2;
    final top = (html.window.screen!.height! - height) ~/ 2;
    
    _log('===== POPUP WITH POLLING AUTHENTICATION START =====');
    _log('Authorization URL: $authorizationUrl');
    _log('Polling ID: $pollingId');
    
    // Open popup window
    final popup = html.window.open(
      authorizationUrl,
      'certilia_auth',
      'width=$width,height=$height,left=$left,top=$top',
    );
    
    // Check if popup was blocked (although it shouldn't be null in dart:html)
    // ignore: unnecessary_null_comparison
    if (popup == null) {
      throw const CertiliaAuthenticationException(
        message: 'Failed to open authentication popup. Please check popup blocker settings.',
      );
    }
    
    _log('Popup opened successfully');
    
    // Start polling for result
    Timer? pollTimer;
    Timer? popupCheckTimer;
    Timer? timeoutTimer;
    bool isPolling = true;
    
    void cleanup() {
      _log('Cleaning up polling timers');
      isPolling = false;
      pollTimer?.cancel();
      popupCheckTimer?.cancel();
      timeoutTimer?.cancel();
    }
    
    // Overall timeout for polling
    timeoutTimer = Timer(const Duration(minutes: 5), () {
      if (!completer.isCompleted) {
        _log('Polling timeout reached after 5 minutes');
        cleanup();
        completer.complete(null);
        try {
          popup.close();
        } catch (_) {}
      }
    });
    
    // Poll server for authentication result
    pollTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      if (!isPolling) return;
      
      try {
        _log('Polling server for auth status...');
        
        final response = await _httpClient.get(
          Uri.parse('$serverUrl/api/auth/polling/$pollingId/status'),
        );
        
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          _log('Poll response: ${data['status']}');
          
          if (data['status'] == 'completed' && data['result'] != null) {
            _log('Authentication completed via polling!');
            _log('Code: ${data['result']['code']}');
            cleanup();
            if (!completer.isCompleted) {
              completer.complete(data['result']['code']);
            }
            // Try multiple methods to close the popup
            // Add small delay to ensure browser is ready
            Timer(const Duration(milliseconds: 100), () {
              try {
                _log('Attempting to close popup...');
                popup.close();
                _log('popup.close() called successfully');
              } catch (e) {
                _log('popup.close() failed: $e');
              }
              // Try closing again after a short delay
              Timer(const Duration(milliseconds: 200), () {
                try {
                  popup.close();
                  _log('Second popup.close() attempt');
                } catch (_) {
                  _log('Second popup.close() attempt failed');
                }
              });
            });
          } else if (data['status'] == 'error') {
            _log('Authentication failed: ${data['error']}');
            cleanup();
            if (!completer.isCompleted) {
              completer.complete(null);
            }
            // Close popup on error
            Timer(const Duration(milliseconds: 100), () {
              try {
                popup.close();
              } catch (_) {}
            });
          }
        } else if (response.statusCode == 404) {
          _log('Polling session expired or not found');
          cleanup();
          if (!completer.isCompleted) {
            completer.complete(null);
          }
        }
      } catch (e) {
        _log('Polling error: $e');
      }
    });
    
    // Check if popup was closed
    popupCheckTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (popup.closed ?? false) {
        _log('Popup was closed by user');
        // Don't immediately complete with null - give polling a chance
        // Wait a bit more for polling to get the result
        Timer(const Duration(seconds: 3), () {
          if (!completer.isCompleted && isPolling) {
            _log('Popup closed and no polling result - completing with null');
            cleanup();
            completer.complete(null);
          }
        });
        // Stop checking popup
        timer.cancel();
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
          // Include current access token so server can extract certilia tokens
          'Authorization': 'Bearer ${_currentToken!.accessToken}',
        },
        body: jsonEncode({
          'refresh_token': _currentToken!.refreshToken,
        }),
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
        tokenType: tokenData['tokenType'] ?? 'Bearer',
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

  /// Get extended user information
  /// This includes all available fields from Certilia API
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
        throw const CertiliaException(
          message: 'Server URL is required for extended user info',
        );
      }

      _log('Fetching extended user info');

      final response = await _httpClient.get(
        Uri.parse('$serverUrl/api/user/extended-info'),
        headers: {
          'Authorization': 'Bearer ${_currentToken!.accessToken}',
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
    if (serverUrl == null) {
      // Direct API call to Certilia
      final response = await _httpClient.get(
        Uri.parse(config.userInfoEndpoint),
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

  /// Gets the current access token
  String? get currentAccessToken => _currentToken?.accessToken;
  
  /// Gets the current refresh token
  String? get currentRefreshToken => _currentToken?.refreshToken;
  
  /// Gets the current ID token
  String? get currentIdToken => _currentToken?.idToken;
  
  /// Gets the token expiry time
  DateTime? get tokenExpiry => _currentToken?.expiresAt;

  /// Disposes of resources
  void dispose() {
    _httpClient.close();
  }
}

/// Alias for platform client
typedef CertiliaPlatformClient = CertiliaWebClient;