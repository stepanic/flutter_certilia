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
            try {
              popup.close();
            } catch (_) {}
          } else if (data['status'] == 'error') {
            _log('Authentication failed: ${data['error']}');
            cleanup();
            if (!completer.isCompleted) {
              completer.complete(null);
            }
            try {
              popup.close();
            } catch (_) {}
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

  // OLD METHOD - Commented out as we now use polling approach for cross-origin scenarios
  // Kept for reference only - see _openAuthPopupWithPolling() above
  /*
  Future<String?> _openAuthPopup(String authorizationUrl, String expectedState) async {
    final completer = Completer<String?>();
    
    // Calculate popup dimensions
    final width = 500;
    final height = 700;
    final left = (html.window.screen!.width! - width) ~/ 2;
    final top = (html.window.screen!.height! - height) ~/ 2;
    
    _log('===== POPUP AUTHENTICATION START =====');
    _log('Authorization URL: $authorizationUrl');
    _log('Expected state: $expectedState');
    _log('Window dimensions: ${width}x$height at position ($left, $top)');
    _log('Current window location: ${html.window.location.href}');
    _log('Server URL: ${serverUrl ?? "null (direct mode)"}');

    // Listen for messages from popup
    StreamSubscription? messageSubscription;
    StreamSubscription? storageSubscription;
    StreamSubscription? hashChangeSubscription;
    Timer? checkTimer;
    Timer? debugTimer;
    Timer? localStorageTimer;
    html.WindowBase? popup;
    
    void cleanup() {
      _log('Cleaning up popup listeners and timers');
      messageSubscription?.cancel();
      storageSubscription?.cancel();
      checkTimer?.cancel();
      debugTimer?.cancel();
      localStorageTimer?.cancel();
      hashChangeSubscription?.cancel();
    }

    // Set up message listener BEFORE opening popup
    _log('Setting up message listener BEFORE opening popup');
    messageSubscription = html.window.onMessage.listen((event) {
      try {
        _log('===== MESSAGE RECEIVED =====');
        _log('Raw message data: ${event.data}');
        _log('Message type: ${event.data.runtimeType}');
        _log('Message origin: ${event.origin}');
        _log('Expected origin (if server): ${serverUrl ?? "any"}');
        
        // Check if message is from our server
        final server = serverUrl;
        if (server != null && !event.origin.startsWith(server)) {
          _log('WARNING: Message from different origin');
          _log('Server URL: $server');
          _log('Event origin: ${event.origin}');
          // For debugging, let's not ignore it immediately
          // return;
        }
        
        // Parse message data
        final data = event.data;
        _log('Processing message data...');
        
        if (data is String) {
          _log('Message is string, attempting JSON parse...');
          Map<String, dynamic>? parsed;
          try {
            parsed = jsonDecode(data);
            _log('JSON parsed successfully: $parsed');
          } catch (e) {
            _log('JSON parse failed: $e');
            return;
          }
          
          if (parsed != null && parsed['type'] == 'certilia_callback') {
            _log('===== CERTILIA CALLBACK DETECTED =====');
            final code = parsed['code'];
            final state = parsed['state'];
            final error = parsed['error'];
            final errorDescription = parsed['errorDescription'];
            
            _log('Callback data:');
            _log('  - code: ${code ?? "null"}');
            _log('  - state: ${state ?? "null"}');
            _log('  - error: ${error ?? "null"}');
            _log('  - errorDescription: ${errorDescription ?? "null"}');
            _log('  - success: ${parsed['success']}');
            
            if (error != null && error != '') {
              _log('Authentication failed with error: $error');
              cleanup();
              completer.complete(null);
              if (popup != null) popup.close();
            } else if (code != null && code != '' && state == expectedState) {
              _log('SUCCESS: Authentication completed!');
              _log('Code received: $code');
              cleanup();
              completer.complete(code);
              if (popup != null) popup.close();
            } else if (state != expectedState) {
              _log('ERROR: State mismatch!');
              _log('Expected: $expectedState');
              _log('Received: $state');
            } else {
              _log('ERROR: Invalid callback data');
              _log('Code empty: ${code == null || code == ''}');
              _log('State match: ${state == expectedState}');
            }
          } else {
            _log('Message type not certilia_callback: ${parsed?['type'] ?? "null"}');
          }
        } else {
          _log('Message is not a string, type: ${data.runtimeType}');
        }
      } catch (e, stack) {
        _log('ERROR processing message: $e');
        _log('Stack trace: $stack');
      }
    });
    
    // Save current URL for redirect callback
    try {
      html.window.sessionStorage['certilia_return_url'] = html.window.location.href;
      _log('Saved return URL to sessionStorage: ${html.window.location.href}');
    } catch (e) {
      _log('Could not save return URL to sessionStorage: $e');
    }
    
    // Open popup window - ensure opener is available
    _log('Opening popup with features: width=$width,height=$height,left=$left,top=$top');
    popup = html.window.open(
      authorizationUrl,
      'certilia_auth',
      'width=$width,height=$height,left=$left,top=$top,toolbar=no,location=yes,directories=no,status=yes,menubar=no,scrollbars=yes,resizable=yes',
    );
    
    // Check if popup was blocked
    // ignore: unnecessary_null_comparison
    if (popup == null) {
      _log('ERROR: Popup was blocked by browser!');
      cleanup();
      throw const CertiliaAuthenticationException(
        message: 'Failed to open authentication popup. Please check popup blocker settings.',
      );
    }
    
    _log('Popup opened successfully');
    _log('Popup object: $popup');
    try {
      _log('Popup location: ${popup.location}');
    } catch (e) {
      _log('Cannot access popup location: $e');
    }
    _log('Window origin: ${html.window.location.origin}');
    _log('IMPORTANT: Cross-origin communication detected!');
    _log('Parent origin: ${html.window.location.origin}');
    _log('Popup will be on: ${serverUrl ?? "Certilia domain"}');
    _log('Due to browser security, window.opener will be null and postMessage may not work');
    _log('Using localStorage as fallback communication method');
    
    // Debug timer to log popup state
    debugTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      _log('DEBUG: Popup closed status: ${popup?.closed ?? 'null'}');
      _log('DEBUG: Completer completed: ${completer.isCompleted}');
    });
    
    // Listen for postMessage from callback page
    messageSubscription = html.window.onMessage.listen((event) {
      try {
        _log('===== MESSAGE RECEIVED =====');
        _log('Raw message data: ${event.data}');
        _log('Message type: ${event.data.runtimeType}');
        _log('Message origin: ${event.origin}');
        _log('Expected origin (if server): ${serverUrl ?? "any"}');
        
        // Check if message is from our server
        final server = serverUrl;
        if (server != null && !event.origin.startsWith(server)) {
          _log('WARNING: Message from different origin');
          _log('Server URL: $server');
          _log('Event origin: ${event.origin}');
          // For debugging, let's not ignore it immediately
          // return;
        }
        
        // Parse message data
        final data = event.data;
        _log('Processing message data...');
        
        if (data is String) {
          _log('Message is string, attempting JSON parse...');
          Map<String, dynamic>? parsed;
          try {
            parsed = jsonDecode(data);
            _log('JSON parsed successfully: $parsed');
          } catch (e) {
            _log('JSON parse failed: $e');
            return;
          }
          
          if (parsed != null && parsed['type'] == 'certilia_callback') {
            _log('===== CERTILIA CALLBACK DETECTED =====');
            final code = parsed['code'];
            final state = parsed['state'];
            final error = parsed['error'];
            final errorDescription = parsed['errorDescription'];
            
            _log('Callback data:');
            _log('  - code: ${code ?? "null"}');
            _log('  - state: ${state ?? "null"}');
            _log('  - error: ${error ?? "null"}');
            _log('  - errorDescription: ${errorDescription ?? "null"}');
            _log('  - success: ${parsed['success']}');
            
            if (error != null && error != '') {
              _log('Authentication failed with error: $error');
              cleanup();
              completer.complete(null);
              popup?.close();
            } else if (code != null && code != '' && state == expectedState) {
              _log('SUCCESS: Authentication completed!');
              _log('Code received: $code');
              cleanup();
              completer.complete(code);
              popup?.close();
            } else if (state != expectedState) {
              _log('ERROR: State mismatch!');
              _log('Expected: $expectedState');
              _log('Received: $state');
            } else {
              _log('ERROR: Invalid callback data');
              _log('Code empty: ${code == null || code == ''}');
              _log('State match: ${state == expectedState}');
            }
          } else {
            _log('Message type not certilia_callback: ${parsed?['type'] ?? "null"}');
          }
        } else {
          _log('Message is not a string, type: ${data.runtimeType}');
        }
      } catch (e, stack) {
        _log('ERROR processing message: $e');
        _log('Stack trace: $stack');
      }
    });
    
    _log('Message listener registered');
    
    // Method 2: Listen for localStorage changes
    const storageKey = 'certilia_auth_callback';
    
    // Clear any old data
    try {
      html.window.localStorage.remove(storageKey);
    } catch (e) {
      _log('Could not clear localStorage: $e');
    }
    
    // Check localStorage periodically
    localStorageTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      try {
        final storageData = html.window.localStorage[storageKey];
        if (storageData != null) {
          _log('===== LOCALSTORAGE DATA FOUND =====');
          _log('Raw data: $storageData');
          
          try {
            final parsed = jsonDecode(storageData);
            if (parsed['type'] == 'certilia_callback') {
              _log('Processing localStorage callback data');
              final code = parsed['code'];
              final state = parsed['state'];
              final error = parsed['error'];
              
              // Clear the storage
              html.window.localStorage.remove(storageKey);
              
              if (error != null && error != '') {
                _log('Authentication failed with error: $error');
                cleanup();
                completer.complete(null);
                popup?.close();
              } else if (code != null && code != '' && state == expectedState) {
                _log('SUCCESS via localStorage: Authentication completed!');
                _log('Code received: $code');
                cleanup();
                completer.complete(code);
                popup?.close();
              }
            }
          } catch (e) {
            _log('Error parsing localStorage data: $e');
          }
        }
      } catch (e) {
        _log('Error checking localStorage: $e');
      }
    });
    
    // Method 3: Listen for storage events
    storageSubscription = html.window.onStorage.listen((event) {
      _log('===== STORAGE EVENT RECEIVED =====');
      _log('Key: ${event.key}');
      _log('New value: ${event.newValue}');
      _log('URL: ${event.url}');
      
      if (event.key == storageKey && event.newValue != null) {
        try {
          final parsed = jsonDecode(event.newValue!);
          if (parsed['type'] == 'certilia_callback') {
            _log('Processing storage event callback data');
            final code = parsed['code'];
            final state = parsed['state'];
            
            if (code != null && code != '' && state == expectedState) {
              _log('SUCCESS via storage event: Authentication completed!');
              cleanup();
              completer.complete(code);
              popup?.close();
            }
          }
        } catch (e) {
          _log('Error processing storage event: $e');
        }
      }
    });
    
    // Check if popup was closed
    checkTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (popup?.closed ?? false) {
        _log('Popup was closed by user');
        cleanup();
        if (!completer.isCompleted) {
          _log('Completing with null (user cancelled)');
          completer.complete(null);
        }
      }
    });
    
    _log('Popup check timer started');
    
    // Method 4: Listen for URL fragment changes (for cross-origin redirect)
    void checkUrlFragment() {
      try {
        final hash = html.window.location.hash;
        if (hash.contains('certilia-callback=')) {
          _log('===== URL FRAGMENT CALLBACK DETECTED =====');
          _log('Hash: $hash');
          
          // Extract the base64 encoded data
          final match = RegExp(r'certilia-callback=([^&]+)').firstMatch(hash);
          if (match != null) {
            final encodedData = match.group(1);
            try {
              final decodedData = utf8.decode(base64.decode(encodedData!));
              final parsed = jsonDecode(decodedData);
              
              _log('Decoded callback data: $parsed');
              
              if (parsed['success'] == true && parsed['code'] != null && parsed['state'] == expectedState) {
                _log('SUCCESS via URL fragment: Authentication completed!');
                cleanup();
                hashChangeSubscription?.cancel();
                completer.complete(parsed['code']);
                
                // Clean up the URL
                html.window.history.replaceState(null, '', html.window.location.pathname);
              }
            } catch (e) {
              _log('Error decoding fragment data: $e');
            }
          }
        }
      } catch (e) {
        _log('Error checking URL fragment: $e');
      }
    }
    
    // Check immediately and on hash change
    checkUrlFragment();
    hashChangeSubscription = html.window.onHashChange.listen((_) {
      _log('Hash change detected');
      checkUrlFragment();
    });
    
    
    _log('Waiting for authentication callback...');
    
    return completer.future;
  }
  */

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
      } else if (response.statusCode == 401) {
        _log('Token expired or invalid, trying to refresh');
        if (_currentToken!.refreshToken != null) {
          await refreshToken();
          // Retry with new token
          return getExtendedUserInfo();
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