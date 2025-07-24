import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:webview_flutter/webview_flutter.dart';

import 'constants.dart';
import 'exceptions/certilia_exception.dart';
import 'models/certilia_config.dart';
import 'models/certilia_token.dart';
import 'models/certilia_user.dart';

/// WebView-based client for Certilia OAuth authentication
/// This client opens authentication in an in-app WebView instead of external browser
class CertiliaWebViewClient {
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

  /// Creates a new [CertiliaWebViewClient]
  CertiliaWebViewClient({
    required this.config,
    this.serverUrl,
    FlutterSecureStorage? secureStorage,
    http.Client? httpClient,
  })  : _secureStorage = secureStorage ?? const FlutterSecureStorage(),
        _httpClient = httpClient ?? http.Client() {
    config.validate();
  }

  /// Authenticates the user using WebView and returns their profile
  Future<CertiliaUser> authenticate(BuildContext context) async {
    try {
      _log('Starting WebView authentication flow');

      // Initialize OAuth flow
      final authData = await _initializeOAuthFlow();
      
      // Show WebView for authentication
      if (!context.mounted) {
        throw const CertiliaAuthenticationException(
          message: 'Context no longer mounted',
        );
      }
      final code = await _showAuthWebView(
        context,
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
        message: 'Server URL is required for WebView authentication',
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

  /// Shows WebView for authentication and returns authorization code
  Future<String?> _showAuthWebView(
    BuildContext context,
    String authorizationUrl,
    String expectedState,
  ) async {
    return await Navigator.push<String?>(
      context,
      MaterialPageRoute(
        builder: (context) => _CertiliaWebViewScreen(
          authorizationUrl: authorizationUrl,
          redirectUrl: '$serverUrl/api/auth/callback',
          expectedState: expectedState,
        ),
      ),
    );
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
      developer.log(message, name: 'CertiliaWebViewClient');
      if (kDebugMode) {
        debugPrint('[CertiliaWebViewClient] $message');
      }
    }
  }

  /// Disposes of resources
  void dispose() {
    _httpClient.close();
  }
}

/// Alias for platform client
typedef CertiliaPlatformClient = CertiliaWebViewClient;

/// WebView screen for OAuth authentication
class _CertiliaWebViewScreen extends StatefulWidget {
  final String authorizationUrl;
  final String redirectUrl;
  final String expectedState;

  const _CertiliaWebViewScreen({
    required this.authorizationUrl,
    required this.redirectUrl,
    required this.expectedState,
  });

  @override
  State<_CertiliaWebViewScreen> createState() => _CertiliaWebViewScreenState();
}

class _CertiliaWebViewScreenState extends State<_CertiliaWebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  void _initializeWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            setState(() {
              _isLoading = progress < 100;
            });
          },
          onPageStarted: (String url) {
            _checkForCallback(url);
          },
          onPageFinished: (String url) {
            _checkForCallback(url);
          },
          onNavigationRequest: (NavigationRequest request) {
            if (_checkForCallback(request.url)) {
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.authorizationUrl));
  }

  bool _checkForCallback(String url) {
    final uri = Uri.parse(url);
    
    // Check if this is our callback URL
    if (url.startsWith(widget.redirectUrl)) {
      final code = uri.queryParameters['code'];
      final state = uri.queryParameters['state'];
      final error = uri.queryParameters['error'];
      
      if (error != null) {
        // Authentication failed
        Navigator.of(context).pop(null);
        return true;
      }
      
      if (code != null && state == widget.expectedState) {
        // Success - return the code
        Navigator.of(context).pop(code);
        return true;
      }
    }
    
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign in with Certilia'),
        actions: [
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
}