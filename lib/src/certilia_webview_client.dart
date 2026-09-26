import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'certilia_native_client.dart';
import 'services/proxy_auth_service.dart';

/// Mobile/desktop client that shows Certilia's login page in an in-app
/// WebView and watches it for the proxy's own callback URL.
///
/// Used when [CertiliaConfig.callbackUrl] is null. The shared OAuth flow
/// (initialize, state check, code exchange, refresh) lives in
/// [CertiliaNativeClient].
class CertiliaWebViewClient extends CertiliaNativeClient {
  CertiliaWebViewClient({
    required super.config,
    required super.serverUrl,
    super.backend,
  }) : super(componentName: 'CertiliaWebViewClient');

  /// The proxy's own callback: the WebView flow needs certilia-server.
  @override
  String get redirectUri => ProxyAuthService.callbackUrlFor(serverUrl);

  @override
  Future<Uri?> obtainCallback(BuildContext context, String authorizationUrl) {
    return Navigator.push<Uri?>(
      context,
      MaterialPageRoute(
        builder: (context) => _CertiliaWebViewScreen(
          authorizationUrl: authorizationUrl,
          redirectUrl: redirectUri,
        ),
      ),
    );
  }
}

/// The client type on mobile and desktop; `certilia_web_client.dart`
/// defines the same name for web.
typedef CertiliaPlatformClient = CertiliaWebViewClient;

/// WebView screen for OAuth authentication
class _CertiliaWebViewScreen extends StatefulWidget {
  final String authorizationUrl;
  final String redirectUrl;

  const _CertiliaWebViewScreen({
    required this.authorizationUrl,
    required this.redirectUrl,
  });

  @override
  State<_CertiliaWebViewScreen> createState() => _CertiliaWebViewScreenState();
}

class _CertiliaWebViewScreenState extends State<_CertiliaWebViewScreen> {
  /// Page is rendered at 80% of native size because Certilia's auth UI is
  /// designed for desktop and is too cramped at phone widths.
  static const double _pageZoom = 0.8;

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
            _injectZoom();
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

  void _injectZoom() {
    final scale = _pageZoom;
    final widthCompensation = (100 / _pageZoom).toStringAsFixed(0);
    _controller.runJavaScript('''
      var viewport = document.querySelector('meta[name="viewport"]');
      if (!viewport) {
        viewport = document.createElement('meta');
        viewport.name = 'viewport';
        viewport.content = 'width=device-width, initial-scale=$scale, maximum-scale=5.0, user-scalable=yes';
        document.head.appendChild(viewport);
      }
      var style = document.createElement('style');
      style.innerHTML = `
        html {
          zoom: $scale;
          -webkit-transform: scale($scale);
          -webkit-transform-origin: 0 0;
          transform: scale($scale);
          transform-origin: 0 0;
        }
        body { width: $widthCompensation%; }
      `;
      document.head.appendChild(style);
    ''');
  }

  bool _checkForCallback(String url) {
    if (!url.startsWith(widget.redirectUrl)) return false;
    final uri = Uri.parse(url);
    final params = uri.queryParameters;
    if (params.containsKey('error') || params.containsKey('code')) {
      _popWithDelay(uri);
      return true;
    }
    return false;
  }

  void _popWithDelay(Uri? result) {
    // Small delay so the WebView finishes its in-flight navigation before we
    // tear it down; otherwise we hit "Navigator: Cannot pop" on some platforms.
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
