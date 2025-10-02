import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:webview_flutter/webview_flutter.dart';

import 'exceptions/certilia_exception.dart';
import 'models/certilia_config.dart';
import 'models/certilia_user.dart';
import 'models/certilia_extended_info.dart';

/// WebView-based client for Certilia OAuth authentication
/// This client opens authentication in an in-app WebView instead of external browser
/// This is a STATELESS implementation - no tokens or user data are stored
class CertiliaWebViewClient {
  /// Configuration for the client
  final CertiliaConfig config;

  /// HTTP client for API requests
  final http.Client _httpClient;

  /// Server base URL (if using middleware server)
  final String? serverUrl;

  /// Creates a new [CertiliaWebViewClient]
  CertiliaWebViewClient({
    required this.config,
    this.serverUrl,
    http.Client? httpClient,
  })  : _httpClient = httpClient ?? http.Client() {
    config.validate();
  }

  /// Authenticates the user using WebView and returns auth data
  /// This is a STATELESS operation - the caller must handle token storage
  Future<Map<String, dynamic>> authenticate(BuildContext context) async {
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

      // Exchange code for tokens (no dialog here - let caller handle UI)
      final tokenData = await _exchangeCodeForTokens(
        code: code,
        state: authData['state'],
        sessionId: authData['session_id'],
      );

      // Return all auth data for caller to handle
      // Caller is responsible for storing tokens if needed
      _log('✅ Authentication successful');
      return {
        'accessToken': tokenData['accessToken'],
        'refreshToken': tokenData['refreshToken'],
        'idToken': tokenData['idToken'],
        'expiresIn': tokenData['expiresIn'],
        'tokenType': tokenData['tokenType'] ?? 'Bearer',
        'user': tokenData['user'],
      };
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

    final initUrl = '$serverUrl/api/auth/initialize?response_type=code&redirect_uri=$serverUrl/api/auth/callback';
    _log('🚀 Initializing OAuth flow: $initUrl');

    // Create a fresh HTTP client for this request
    final client = http.Client();
    try {
      final response = await client.get(
        Uri.parse(initUrl),
        headers: {
          'ngrok-skip-browser-warning': 'true',
        },
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          _log('⏱️ Initialize request timed out');
          throw CertiliaNetworkException(
            message: 'Initialize request timed out',
            statusCode: 408,
            details: 'Request timed out after 10 seconds',
          );
        },
      );

      _log('📥 Initialize response status: ${response.statusCode}');

      if (response.statusCode != 200) {
        _log('❌ Initialize failed: ${response.body}');
        throw CertiliaNetworkException(
          message: 'Failed to initialize OAuth flow',
          statusCode: response.statusCode,
          details: response.body,
        );
      }

      final data = jsonDecode(response.body);
      _log('✅ OAuth initialized - Session ID: ${data['session_id']}, State: ${data['state']}');
      return data;
    } finally {
      client.close();
    }

  }

  /// Shows WebView for authentication and returns authorization code
  Future<String?> _showAuthWebView(
    BuildContext context,
    String authorizationUrl,
    String expectedState,
  ) async {
    final code = await Navigator.push<String?>(
      context,
      MaterialPageRoute(
        builder: (context) => _CertiliaWebViewScreen(
          authorizationUrl: authorizationUrl,
          redirectUrl: '$serverUrl/api/auth/callback',
          expectedState: expectedState,
        ),
      ),
    );

    // Don't show dialog here - it will be shown in authenticate method if needed
    // This prevents duplicate dialogs and stuck dialogs

    return code;
  }

  /// Exchange authorization code for tokens with retry logic
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

    _log('🔄 Starting token exchange - Code: ${code.substring(0, 10 > code.length ? code.length : 10)}..., State: $state, Session: $sessionId');

    // Retry logic for flaky network connections
    int retries = 3;
    http.Response? response;
    Exception? lastError;

    for (int i = 0; i < retries; i++) {
      try {
        _log('🔄 Token exchange attempt ${i + 1} of $retries');

        // Create a new HTTP client for each retry attempt
        final client = http.Client();
        try {
          final exchangeBody = {
            'code': code,
            'state': state,
            'session_id': sessionId,
          };
          _log('📤 Sending exchange request to: $serverUrl/api/auth/exchange');
          _log('📤 Request body: ${jsonEncode(exchangeBody)}');

          response = await client.post(
            Uri.parse('$serverUrl/api/auth/exchange'),
            headers: {
              'Content-Type': 'application/json',
              'ngrok-skip-browser-warning': 'true',
            },
            body: jsonEncode(exchangeBody),
          ).timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              _log('⏱️ Token exchange timed out after 30 seconds');
              throw CertiliaNetworkException(
                message: 'Token exchange timed out',
                statusCode: 408,
                details: 'Request timed out after 30 seconds',
              );
            },
          );

          _log('📥 Exchange response status: ${response.statusCode}');

          // If we got a response, break out of retry loop
          break;
        } finally {
          client.close();
        }
      } catch (e) {
        lastError = e as Exception;
        _log('❌ Token exchange attempt ${i + 1} failed: $e');

        // If this isn't the last retry, wait before trying again
        if (i < retries - 1) {
          await Future.delayed(Duration(seconds: i + 1));
        }
      }
    }

    if (response == null) {
      _log('💥 All token exchange attempts failed');
      throw lastError ?? CertiliaNetworkException(
        message: 'Failed to exchange code for tokens after $retries attempts',
        statusCode: 0,
        details: 'All retry attempts failed',
      );
    }

    if (response.statusCode != 200) {
      _log('❌ Token exchange failed with status ${response.statusCode}: ${response.body}');
      throw CertiliaNetworkException(
        message: 'Failed to exchange code for tokens',
        statusCode: response.statusCode,
        details: response.body,
      );
    }

    final data = jsonDecode(response.body);
    _log('✅ Token exchange successful');
    _log('🔐 Received tokens - hasAccessToken: ${data['accessToken'] != null}, hasRefreshToken: ${data['refreshToken'] != null}, hasIdToken: ${data['idToken'] != null}');
    if (data['user'] != null) {
      _log('👤 User data received: ${(data['user'] as Map).keys.toList()}');
    }

    return data;
  }

  /// Fetches current user info using an access token
  /// This is a STATELESS operation - caller must provide valid token
  Future<CertiliaUser?> getUserInfo(String accessToken) async {
    try {
      _log('📝 Getting user info with provided token...');
      return await _fetchUserInfo(accessToken);
    } catch (e) {
      _log('❌ Failed to get user info: $e');
      return null;
    }
  }

  /// Refreshes the access token using the refresh token
  /// This is a STATELESS operation - caller must provide tokens and handle storage
  Future<Map<String, dynamic>> refreshToken({
    required String accessToken,
    required String refreshToken,
  }) async {
    if (serverUrl == null) {
      throw const CertiliaException(
        message: 'Server URL is required for token refresh',
      );
    }

    try {
      _log('🔄 Refreshing token');

      // Create a fresh HTTP client for this request
      final client = http.Client();
      try {
        final response = await client.post(
          Uri.parse('$serverUrl/api/auth/refresh'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $accessToken',
            'ngrok-skip-browser-warning': 'true',
          },
          body: jsonEncode({
            'refresh_token': refreshToken,
          }),
        ).timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            throw CertiliaNetworkException(
              message: 'Token refresh timed out',
              statusCode: 408,
              details: 'Request timed out after 10 seconds',
            );
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
        _log('✅ Token refreshed successfully');
        _log('📝 Response data: ${jsonEncode(tokenData)}');

        // Log token details
        _log('🔑 New Access Token (first 20): ${tokenData['accessToken']?.toString().substring(0, 20)}...');
        _log('🔑 Has Refresh Token: ${tokenData['refreshToken'] != null}');
        _log('⏰ Expires In: ${tokenData['expiresIn']} seconds');

        // Return refreshed token data for caller to handle
        return {
          'accessToken': tokenData['accessToken'],
          'refreshToken': tokenData['refreshToken'] ?? refreshToken,
          'idToken': tokenData['idToken'],
          'expiresIn': tokenData['expiresIn'],
          'tokenType': tokenData['tokenType'] ?? 'Bearer',
        };
      } finally {
        client.close();
      }
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

  /// Get extended user information using an access token
  /// This is a STATELESS operation - caller must provide valid token
  Future<CertiliaExtendedInfo?> getExtendedUserInfo(String accessToken) async {
    try {
      if (serverUrl == null) {
        throw const CertiliaException(
          message: 'Server URL is required for extended user info',
        );
      }

      _log('📡 Fetching extended user info from: $serverUrl/api/user/extended-info');

      // Create a fresh HTTP client for this request
      final client = http.Client();
      try {
        final response = await client.get(
          Uri.parse('$serverUrl/api/user/extended-info'),
          headers: {
            'Authorization': 'Bearer $accessToken',
            'ngrok-skip-browser-warning': 'true',
          },
        );

        _log('📥 Response status code: ${response.statusCode}');

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          _log('✅ Extended user info fetched successfully');
          return CertiliaExtendedInfo.fromJson(data);
        } else if (response.statusCode == 401 || response.statusCode == 502) {
          _log('⚠️ Token might be expired or server error (${response.statusCode})');
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
            // Inject CSS to zoom the page to 80%
            _controller.runJavaScript('''
              // Add viewport meta tag if not exists
              var viewport = document.querySelector('meta[name="viewport"]');
              if (!viewport) {
                viewport = document.createElement('meta');
                viewport.name = 'viewport';
                viewport.content = 'width=device-width, initial-scale=0.8, maximum-scale=5.0, user-scalable=yes';
                document.head.appendChild(viewport);
              }
              
              // Add CSS for zoom
              var style = document.createElement('style');
              style.innerHTML = `
                html {
                  zoom: 0.8;
                  -webkit-transform: scale(0.8);
                  -webkit-transform-origin: 0 0;
                  -moz-transform: scale(0.8);
                  -moz-transform-origin: 0 0;
                  transform: scale(0.8);
                  transform-origin: 0 0;
                }
                body {
                  width: 125%; /* Compensate for 0.8 scale */
                }
              `;
              document.head.appendChild(style);
            ''');
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