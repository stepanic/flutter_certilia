import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'exceptions/certilia_exception.dart';
import 'models/certilia_config.dart';
import 'models/certilia_extended_info.dart';
import 'models/certilia_user.dart';
import 'services/certilia_logger.dart';
import 'services/proxy_auth_service.dart';

/// WebView-based stateless OAuth client for mobile/desktop targets.
///
/// All HTTP communication with the proxy server lives in [ProxyAuthService];
/// this class owns only the in-app WebView lifecycle. Stateless — callers
/// (typically [CertiliaStatefulWrapper]) handle token storage.
class CertiliaWebViewClient {
  final CertiliaConfig config;
  final String serverUrl;
  final ProxyAuthService _proxy;
  final CertiliaLogger _logger;

  CertiliaWebViewClient({
    required this.config,
    required this.serverUrl,
    ProxyAuthService? proxyService,
  })  : _logger = CertiliaLogger(
          componentName: 'CertiliaWebViewClient',
          enableLogging: config.enableLogging,
        ),
        _proxy = proxyService ??
            ProxyAuthService(
              serverUrl: serverUrl,
              logger: CertiliaLogger(
                componentName: 'CertiliaWebViewClient.proxy',
                enableLogging: config.enableLogging,
              ),
            ) {
    config.validate();
  }

  /// Runs the full WebView OAuth flow. Returns the raw token bundle from
  /// `/api/auth/exchange` (`accessToken`, `refreshToken`, `idToken`,
  /// `expiresIn`, `tokenType`, `user`).
  Future<Map<String, dynamic>> authenticate(BuildContext context) async {
    try {
      _logger.log('Starting WebView authentication flow');
      final authData = await _proxy.initialize();

      if (!context.mounted) {
        throw const CertiliaAuthenticationException(
          message: 'Context no longer mounted',
        );
      }

      final code = await _showAuthWebView(
        context,
        authData['authorization_url'] as String,
        authData['state'] as String,
      );

      if (code == null) {
        throw const CertiliaAuthenticationException(
          message: 'Authentication was cancelled',
        );
      }

      final tokenData = await _proxy.exchange(
        code: code,
        state: authData['state'] as String,
        sessionId: authData['session_id'] as String,
      );

      _logger.log('Authentication successful');
      return {
        'accessToken': tokenData['accessToken'],
        'refreshToken': tokenData['refreshToken'],
        'idToken': tokenData['idToken'],
        'expiresIn': tokenData['expiresIn'],
        'tokenType': tokenData['tokenType'] ?? 'Bearer',
        'user': tokenData['user'],
      };
    } catch (e) {
      _logger.log('Authentication failed: $e');
      if (e is CertiliaException) rethrow;
      throw CertiliaAuthenticationException(
        message: 'Authentication failed',
        details: e.toString(),
      );
    }
  }

  /// Refreshes tokens. Returns the new token bundle.
  Future<Map<String, dynamic>> refreshToken({
    required String accessToken,
    required String refreshToken,
  }) async {
    try {
      _logger.log('Refreshing token');
      final tokenData = await _proxy.refresh(
        accessToken: accessToken,
        refreshToken: refreshToken,
      );
      _logger.log('Token refreshed successfully');
      return {
        'accessToken': tokenData['accessToken'],
        'refreshToken': tokenData['refreshToken'] ?? refreshToken,
        'idToken': tokenData['idToken'],
        'expiresIn': tokenData['expiresIn'],
        'tokenType': tokenData['tokenType'] ?? 'Bearer',
      };
    } catch (e) {
      _logger.log('Token refresh failed: $e');
      if (e is CertiliaException) rethrow;
      throw CertiliaAuthenticationException(
        message: 'Failed to refresh token',
        details: e.toString(),
      );
    }
  }

  /// Fetches basic user info using the supplied access token.
  /// Returns null on failure rather than throwing — callers expect this.
  Future<CertiliaUser?> getUserInfo(String accessToken) async {
    try {
      return await _proxy.fetchUserInfo(accessToken);
    } catch (e) {
      _logger.log('Failed to get user info: $e');
      return null;
    }
  }

  /// Fetches extended user info using the supplied access token.
  /// Returns null on 401/502 so the caller can refresh and retry.
  Future<CertiliaExtendedInfo?> getExtendedUserInfo(String accessToken) {
    return _proxy.fetchExtendedInfo(accessToken);
  }

  Future<String?> _showAuthWebView(
    BuildContext context,
    String authorizationUrl,
    String expectedState,
  ) {
    return Navigator.push<String?>(
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

  void dispose() => _proxy.close();
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
          onProgress: (progress) {
            setState(() => _isLoading = progress < 100);
          },
          onPageStarted: (url) => _checkForCallback(url),
          onPageFinished: (url) {
            _checkForCallback(url);
            // 80% zoom for better readability on phones (Certilia's auth UI
            // is sized for desktop).
            _controller.runJavaScript('''
              var viewport = document.querySelector('meta[name="viewport"]');
              if (!viewport) {
                viewport = document.createElement('meta');
                viewport.name = 'viewport';
                viewport.content = 'width=device-width, initial-scale=0.8, maximum-scale=5.0, user-scalable=yes';
                document.head.appendChild(viewport);
              }
              var style = document.createElement('style');
              style.innerHTML = `
                html {
                  zoom: 0.8;
                  -webkit-transform: scale(0.8);
                  -webkit-transform-origin: 0 0;
                  transform: scale(0.8);
                  transform-origin: 0 0;
                }
                body { width: 125%; }
              `;
              document.head.appendChild(style);
            ''');
          },
          onNavigationRequest: (request) {
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
    if (!url.startsWith(widget.redirectUrl)) return false;
    final uri = Uri.parse(url);
    final code = uri.queryParameters['code'];
    final state = uri.queryParameters['state'];
    final error = uri.queryParameters['error'];

    if (error != null) {
      _popWithDelay(null);
      return true;
    }
    if (code != null && state == widget.expectedState) {
      _popWithDelay(code);
      return true;
    }
    return false;
  }

  void _popWithDelay(String? result) {
    // Small delay so the WebView finishes its in-flight navigation before we
    // tear it down — otherwise we hit "Navigator: Cannot pop" on some platforms.
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop(result);
      }
    });
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
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
}
