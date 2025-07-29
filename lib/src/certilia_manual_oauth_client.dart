import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:url_launcher/url_launcher.dart';

import 'exceptions/certilia_exception.dart';
import 'models/certilia_config.dart';
import 'models/certilia_extended_info.dart';
import 'models/certilia_token.dart';
import 'models/certilia_user.dart';

/// Manual OAuth client that uses url_launcher and polling
/// This is a hybrid approach for when AppAuth can't handle the redirect
class CertiliaManualOAuthClient {
  /// Configuration for the client
  final CertiliaConfig config;

  /// Secure storage for tokens
  final FlutterSecureStorage _secureStorage;

  /// HTTP client for API requests
  final http.Client _httpClient;

  /// Server base URL (required for this approach)
  final String? serverUrl;

  /// Current authentication token
  CertiliaToken? _currentToken;

  /// Storage key for tokens
  static const String _tokenStorageKey = 'certilia_token';

  /// Creates a new [CertiliaManualOAuthClient]
  CertiliaManualOAuthClient({
    required this.config,
    required this.serverUrl,
    FlutterSecureStorage? secureStorage,
    http.Client? httpClient,
  })  : _secureStorage = secureStorage ?? const FlutterSecureStorage(),
        _httpClient = httpClient ?? _createHttpClient() {
    config.validate();
    if (serverUrl == null) {
      throw ArgumentError('serverUrl is required for manual OAuth flow');
    }
    // Load saved tokens on initialization
    _initializeTokens();
  }

  /// Create HTTP client with custom configuration for ngrok
  static http.Client _createHttpClient() {
    if (kIsWeb) {
      return http.Client();
    }
    
    final httpClient = HttpClient()
      ..badCertificateCallback = (cert, host, port) {
        // Accept ngrok certificates
        return host.endsWith('.ngrok-free.app') || host.endsWith('.ngrok.io');
      };
    
    return IOClient(httpClient);
  }

  /// Initialize tokens from storage
  Future<void> _initializeTokens() async {
    try {
      await _loadToken();
      if (_currentToken != null && !_currentToken!.isExpired) {
        _log('Loaded saved authentication token');
      }
    } catch (e) {
      _log('Failed to load saved tokens: $e');
    }
  }

  /// Authenticates the user using native browser and polling
  Future<CertiliaUser> authenticate(BuildContext context) async {
    try {
      _log('Starting manual OAuth authentication flow');
      
      // Initialize OAuth flow
      final initResponse = await _initializeOAuthFlow();
      final authUrl = initResponse['authorization_url'] as String;
      final sessionId = initResponse['session_id'] as String;
      final state = initResponse['state'] as String;
      
      // Start polling session on server
      final pollingData = await _startPollingSession(
        state: state,
        sessionId: sessionId,
      );
      final pollingId = pollingData['polling_id'] as String;
      
      _log('Opening browser for authentication');
      _log('Session ID: $sessionId');
      _log('Polling ID: $pollingId');
      
      // Open browser and start polling concurrently
      final authFuture = _performAuthenticationFlow(
        authUrl: authUrl,
        pollingId: pollingId,
        state: state,
        sessionId: sessionId,
      );
      
      // Wait for authentication to complete
      final user = await authFuture;
      
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
  
  /// Performs the authentication flow with browser and polling
  Future<CertiliaUser> _performAuthenticationFlow({
    required String authUrl,
    required String pollingId,
    required String state,
    required String sessionId,
  }) async {
    // Use inAppWebView on mobile to have more control
    final launchMode = kIsWeb 
        ? LaunchMode.platformDefault 
        : LaunchMode.inAppWebView;
    
    // Track if browser is still open
    bool browserClosed = false;
    
    // Launch browser
    final browserLaunched = await launchUrl(
      Uri.parse(authUrl),
      mode: launchMode,
    );
    
    if (!browserLaunched) {
      throw const CertiliaException(
        message: 'Could not launch browser for authentication',
      );
    }
    
    _log('Browser opened, starting to poll for result');
    
    // Start polling with browser close on success
    try {
      final result = await _pollForAuthResult(
        pollingId, 
        state,
        onSuccess: () async {
          // Close the browser when authentication succeeds
          if (!browserClosed && !kIsWeb) {
            browserClosed = true;
            try {
              // On mobile, we can try to close all browser activities
              await closeInAppWebView();
              _log('In-app browser closed after successful authentication');
            } catch (e) {
              _log('Could not close in-app browser: $e');
            }
          }
        },
      );
      
      if (result == null) {
        throw const CertiliaAuthenticationException(
          message: 'Authentication timed out or was cancelled',
        );
      }
      
      _log('Got authentication result, exchanging code for tokens');
      
      // Exchange code for tokens
      final tokenData = await _exchangeCodeForTokens(
        code: result['code'],
        state: result['state'],
        sessionId: sessionId,
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
      
      // Extract user from response
      final user = tokenData['user'] != null
          ? CertiliaUser.fromJson(tokenData['user'])
          : await _fetchUserInfo(_currentToken!.accessToken);
      
      return user;
    } finally {
      // Ensure browser is closed even on error
      if (!browserClosed && !kIsWeb) {
        try {
          await closeInAppWebView();
        } catch (_) {}
      }
    }
  }

  /// Initialize OAuth flow with the server
  Future<Map<String, dynamic>> _initializeOAuthFlow() async {
    final uri = Uri.parse('$serverUrl/api/auth/initialize').replace(
      queryParameters: {
        'response_type': 'code',
        'redirect_uri': config.redirectUrl,
      },
    );
    
    _log('Initializing OAuth flow with URL: $uri');
    
    try {
      final response = await _httpClient.get(
        uri,
        headers: {
          'ngrok-skip-browser-warning': 'true',
          'User-Agent': 'Flutter/CertiliaOAuth',
        },
      );
      
      if (response.statusCode != 200) {
        throw CertiliaNetworkException(
          message: 'Failed to initialize OAuth flow',
          statusCode: response.statusCode,
          details: response.body,
        );
      }
      
      return jsonDecode(response.body);
    } catch (e) {
      _log('Network error during initialization: $e');
      if (e.toString().contains('Failed host lookup')) {
        throw CertiliaNetworkException(
          message: 'Cannot connect to server. Please check your internet connection.',
          statusCode: 0,
          details: 'DNS lookup failed for: $serverUrl',
        );
      }
      rethrow;
    }
  }

  /// Start polling session on server
  Future<Map<String, dynamic>> _startPollingSession({
    required String state,
    required String sessionId,
  }) async {
    _log('Starting polling session for state: $state');
    
    final response = await _httpClient.post(
      Uri.parse('$serverUrl/api/auth/polling/start'),
      headers: {
        'Content-Type': 'application/json',
        'ngrok-skip-browser-warning': 'true',
      },
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

  /// Poll server for authentication result
  Future<Map<String, dynamic>?> _pollForAuthResult(
    String pollingId,
    String expectedState, {
    Future<void> Function()? onSuccess,
  }) async {
    const maxAttempts = 300; // 5 minutes total
    const initialInterval = Duration(seconds: 2);
    const maxInterval = Duration(seconds: 5);
    
    var currentInterval = initialInterval;
    var consecutiveErrors = 0;
    
    for (int i = 0; i < maxAttempts; i++) {
      try {
        // Create fresh HTTP client for each request to avoid connection issues
        final client = _createHttpClient();
        try {
          final response = await client.get(
            Uri.parse('$serverUrl/api/auth/polling/$pollingId/status'),
            headers: {
              'ngrok-skip-browser-warning': 'true',
              'User-Agent': 'Flutter/CertiliaOAuth',
            },
          ).timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw TimeoutException('Polling request timed out');
            },
          );
          
          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            _log('Poll response: ${data['status']}');
            
            // Reset error counter on successful response
            consecutiveErrors = 0;
            currentInterval = initialInterval;
            
            if (data['status'] == 'completed' && data['result'] != null) {
              _log('Authentication completed via polling!');
              _log('Code: ${data['result']['code']}');
              
              // Verify state
              if (data['result']['state'] != expectedState) {
                throw const CertiliaAuthenticationException(
                  message: 'Invalid state parameter',
                );
              }
              
              // Call onSuccess callback if provided
              if (onSuccess != null) {
                await onSuccess();
              }
              
              return {
                'code': data['result']['code'],
                'state': data['result']['state'],
              };
            } else if (data['status'] == 'error') {
              throw CertiliaAuthenticationException(
                message: 'Authentication failed',
                details: data['error'],
              );
            }
          } else if (response.statusCode == 404) {
            _log('Polling session expired or not found');
            return null;
          }
        } finally {
          client.close();
        }
      } catch (e) {
        consecutiveErrors++;
        
        if (e is CertiliaException) {
          rethrow;
        }
        
        // Log error but continue polling
        _log('Polling error (attempt ${i + 1}, consecutive errors: $consecutiveErrors): $e');
        
        // Exponential backoff on errors
        if (consecutiveErrors > 3) {
          currentInterval = maxInterval;
        }
      }
      
      // Wait before next poll
      await Future.delayed(currentInterval);
    }
    
    return null; // Timed out
  }

  /// Exchange authorization code for tokens
  Future<Map<String, dynamic>> _exchangeCodeForTokens({
    required String code,
    required String state,
    required String sessionId,
  }) async {
    final response = await _httpClient.post(
      Uri.parse('$serverUrl/api/auth/exchange'),
      headers: {
        'Content-Type': 'application/json',
        'ngrok-skip-browser-warning': 'true',
      },
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
      if (_currentToken == null) {
        await _loadToken();
      }
      
      if (_currentToken == null || _currentToken!.isExpired) {
        return null;
      }
      
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
      
      final response = await _httpClient.post(
        Uri.parse('$serverUrl/api/auth/refresh'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${_currentToken!.accessToken}',
          'ngrok-skip-browser-warning': 'true',
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
  Future<CertiliaExtendedInfo?> getExtendedUserInfo() async {
    try {
      if (_currentToken == null || _currentToken!.isExpired) {
        _log('No valid token available for extended info');
        return null;
      }
      
      _log('Fetching extended user info');
      
      final response = await _httpClient.get(
        Uri.parse('$serverUrl/api/user/extended-info'),
        headers: {
          'Authorization': 'Bearer ${_currentToken!.accessToken}',
          'ngrok-skip-browser-warning': 'true',
        },
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _log('Extended user info fetched successfully');
        return CertiliaExtendedInfo.fromJson(data);
      } else if (response.statusCode == 401) {
        _log('Token expired, clearing authentication');
        await logout();
        return null;
      } else {
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

  /// Checks authentication status including loading from storage
  Future<bool> checkAuthenticationStatus() async {
    if (_currentToken == null) {
      await _loadToken();
    }
    return isAuthenticated;
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
      developer.log(message, name: 'CertiliaManualOAuth');
      if (kDebugMode) {
        debugPrint('[CertiliaManualOAuth] $message');
      }
    }
  }

  /// Disposes of resources
  void dispose() {
    _httpClient.close();
  }
}

/// Alias for platform client
typedef CertiliaPlatformClient = CertiliaManualOAuthClient;