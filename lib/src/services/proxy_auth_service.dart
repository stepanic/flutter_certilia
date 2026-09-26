import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../exceptions/certilia_exception.dart';
import '../models/certilia_extended_info.dart';
import '../models/certilia_user.dart';
import 'certilia_auth_backend.dart';
import 'certilia_logger.dart';

/// HTTP client for the certilia-server proxy.
///
/// Makes every request the SDK sends to the proxy: starting the login,
/// exchanging the code (with retries), refreshing, and fetching the basic
/// and extended profile. It keeps no tokens; callers store them.
class ProxyAuthService implements CertiliaAuthBackend {
  final String serverUrl;
  final http.Client _httpClient;
  final CertiliaLogger _logger;

  static const Duration _initializeTimeout = Duration(seconds: 10);
  static const Duration _exchangeTimeout = Duration(seconds: 30);
  static const Duration _refreshTimeout = Duration(seconds: 10);
  static const int _exchangeRetries = 3;

  /// Extra headers are sent only outside the web. On web, a custom header
  /// makes the browser send a CORS preflight, and certilia-server allows only
  /// `Content-Type` and `Authorization`, so the request would be blocked.
  /// Elsewhere `ngrok-skip-browser-warning` keeps an ngrok tunnel from
  /// answering with its warning page.
  static final Map<String, String> _baseHeaders = kIsWeb
      ? const <String, String>{}
      : const <String, String>{'ngrok-skip-browser-warning': 'true'};

  ProxyAuthService({
    required this.serverUrl,
    required CertiliaLogger logger,
    http.Client? httpClient,
  })  : _httpClient = httpClient ?? http.Client(),
        _logger = logger;

  /// The callback of the proxy at [serverUrl], used by the mobile WebView
  /// flow, which watches for this URL.
  static String callbackUrlFor(String serverUrl) =>
      '$serverUrl/api/auth/callback';

  /// [callbackUrlFor] this proxy.
  String get proxyCallbackUrl => callbackUrlFor(serverUrl);

  /// GET /api/auth/initialize: returns `authorization_url`, `state`, `session_id`.
  ///
  /// [redirectUri] is where Certilia sends the browser after login. It
  /// defaults to [proxyCallbackUrl]. The proxy picks the Certilia client
  /// registered for this URI.
  @override
  Future<Map<String, dynamic>> initialize({String? redirectUri}) async {
    final url = '$serverUrl/api/auth/initialize'
        '?response_type=code'
        '&redirect_uri=${Uri.encodeQueryComponent(redirectUri ?? proxyCallbackUrl)}';
    _logger.log('Initializing OAuth flow: $url');

    final response = await _httpClient
        .get(Uri.parse(url), headers: _baseHeaders)
        .timeout(_initializeTimeout, onTimeout: () => throw _timeout('initialize'));

    if (response.statusCode != 200) {
      throw CertiliaNetworkException(
        message: 'Failed to initialize OAuth flow',
        statusCode: response.statusCode,
        details: response.body,
      );
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// POST /api/auth/exchange: exchanges the code for tokens. Retries after a
  /// timeout or connection error.
  @override
  Future<Map<String, dynamic>> exchange({
    required String code,
    required String state,
    required String sessionId,
  }) async {
    final body = jsonEncode({
      'code': code,
      'state': state,
      'session_id': sessionId,
    });

    Exception? lastError;
    for (var attempt = 1; attempt <= _exchangeRetries; attempt++) {
      _logger.log('Token exchange attempt $attempt of $_exchangeRetries');
      try {
        final response = await _httpClient
            .post(
              Uri.parse('$serverUrl/api/auth/exchange'),
              headers: {
                ..._baseHeaders,
                'Content-Type': 'application/json',
              },
              body: body,
            )
            .timeout(_exchangeTimeout, onTimeout: () => throw _timeout('exchange'));

        if (response.statusCode != 200) {
          throw CertiliaNetworkException(
            message: 'Failed to exchange code for tokens',
            statusCode: response.statusCode,
            details: response.body,
          );
        }
        return jsonDecode(response.body) as Map<String, dynamic>;
      } on CertiliaNetworkException catch (e) {
        // A non-200 answer from the proxy is final; only a timeout (408) is
        // retried.
        if (e.statusCode != 408) rethrow;
        lastError = e;
      } catch (e) {
        lastError = e is Exception ? e : Exception(e.toString());
        _logger.log('Token exchange attempt $attempt failed: $e');
      }
      if (attempt < _exchangeRetries) {
        await Future.delayed(Duration(seconds: attempt));
      }
    }

    throw lastError ??
        const CertiliaNetworkException(
          message: 'Token exchange failed after retries',
          statusCode: 0,
        );
  }

  /// POST /api/auth/refresh: returns refreshed token bundle.
  ///
  /// Both tokens are sent in the JSON body. The server also accepts the
  /// access token in the Authorization header, which this SDK does not use.
  /// [idToken] is not sent: the proxy keeps Certilia's tokens itself.
  @override
  Future<Map<String, dynamic>> refresh({
    required String accessToken,
    required String refreshToken,
    String? idToken,
  }) async {
    final response = await _httpClient
        .post(
          Uri.parse('$serverUrl/api/auth/refresh'),
          headers: {
            ..._baseHeaders,
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'refresh_token': refreshToken,
            'access_token': accessToken,
          }),
        )
        .timeout(_refreshTimeout, onTimeout: () => throw _timeout('refresh'));

    if (response.statusCode != 200) {
      throw CertiliaNetworkException(
        message: 'Token refresh failed',
        statusCode: response.statusCode,
        details: response.body,
      );
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// GET /api/auth/user: basic profile. Throws on non-200.
  @override
  Future<CertiliaUser> fetchUserInfo(String accessToken,
      {String? idToken}) async {
    final response = await _httpClient.get(
      Uri.parse('$serverUrl/api/auth/user'),
      headers: {
        ..._baseHeaders,
        'Authorization': 'Bearer $accessToken',
      },
    );
    if (response.statusCode != 200) {
      throw CertiliaNetworkException(
        message: 'Failed to fetch user info',
        statusCode: response.statusCode,
        details: response.body,
      );
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return CertiliaUser.fromJson(json['user'] as Map<String, dynamic>);
  }

  /// GET /api/user/extended-info: full profile.
  ///
  /// Returns null on 401/502 to let callers decide whether to refresh the
  /// token and retry. Throws on other non-200 statuses.
  @override
  Future<CertiliaExtendedInfo?> fetchExtendedInfo(String accessToken,
      {String? idToken}) async {
    final response = await _httpClient.get(
      Uri.parse('$serverUrl/api/user/extended-info'),
      headers: {
        ..._baseHeaders,
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return CertiliaExtendedInfo.fromJson(data);
    }
    if (response.statusCode == 401 || response.statusCode == 502) {
      _logger.log('Extended info: token expired or upstream error '
          '(${response.statusCode})');
      return null;
    }
    throw CertiliaNetworkException(
      message: 'Failed to fetch extended user info',
      statusCode: response.statusCode,
      details: response.body,
    );
  }

  @override
  void close() => _httpClient.close();

  CertiliaNetworkException _timeout(String op) => CertiliaNetworkException(
        message: '$op request timed out',
        statusCode: 408,
        details: 'Request timed out',
      );
}
