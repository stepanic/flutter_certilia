import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../exceptions/certilia_exception.dart';
import '../models/certilia_extended_info.dart';
import '../models/certilia_user.dart';
import 'certilia_logger.dart';

/// HTTP client for the certilia-server proxy.
///
/// Owns every request the SDK makes against the proxy: OAuth init, polling
/// session lifecycle (web), code-for-token exchange (with retry), refresh,
/// user info, and extended info. Stateless — callers manage tokens.
class ProxyAuthService {
  final String serverUrl;
  final http.Client _httpClient;
  final CertiliaLogger _logger;

  static const Duration _initializeTimeout = Duration(seconds: 10);
  static const Duration _exchangeTimeout = Duration(seconds: 30);
  static const Duration _refreshTimeout = Duration(seconds: 10);
  static const int _exchangeRetries = 3;

  /// Custom headers only travel on non-web platforms. On web, custom headers
  /// trigger CORS preflight; the proxy server's CORS config only whitelists
  /// `Content-Type` and `Authorization`, so anything extra (e.g. the
  /// ngrok-skip warning header used by in-app WebViews) would block requests.
  static final Map<String, String> _baseHeaders = kIsWeb
      ? const <String, String>{}
      : const <String, String>{'ngrok-skip-browser-warning': 'true'};

  ProxyAuthService({
    required this.serverUrl,
    required CertiliaLogger logger,
    http.Client? httpClient,
  })  : _httpClient = httpClient ?? http.Client(),
        _logger = logger;

  /// GET /api/auth/initialize — returns `authorization_url`, `state`, `session_id`.
  Future<Map<String, dynamic>> initialize() async {
    final url = '$serverUrl/api/auth/initialize'
        '?response_type=code'
        '&redirect_uri=$serverUrl/api/auth/callback';
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

  /// POST /api/auth/polling/start — web popup flow only.
  Future<Map<String, dynamic>> startPollingSession({
    required String state,
    required String sessionId,
  }) async {
    final response = await _httpClient.post(
      Uri.parse('$serverUrl/api/auth/polling/start'),
      headers: {
        ..._baseHeaders,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'state': state, 'session_id': sessionId}),
    );

    if (response.statusCode != 200) {
      throw CertiliaNetworkException(
        message: 'Failed to start polling session',
        statusCode: response.statusCode,
        details: response.body,
      );
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// GET /api/auth/polling/:id/status — web popup flow only.
  /// Returns the raw response shape (`status`, optional `result`, optional `error`).
  Future<Map<String, dynamic>?> pollStatus(String pollingId) async {
    final response = await _httpClient.get(
      Uri.parse('$serverUrl/api/auth/polling/$pollingId/status'),
      headers: _baseHeaders,
    );
    if (response.statusCode == 404) {
      return null;
    }
    if (response.statusCode != 200) {
      throw CertiliaNetworkException(
        message: 'Polling status request failed',
        statusCode: response.statusCode,
        details: response.body,
      );
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// POST /api/auth/exchange — code → tokens. Retries on transient failure.
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
        // Non-200 responses are terminal — don't retry the server's "no".
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

  /// POST /api/auth/refresh — returns refreshed token bundle.
  ///
  /// Both tokens travel in the JSON body. Earlier versions of this SDK put
  /// the access token in the Authorization header; the server still accepts
  /// that for backward compatibility but new code should use the body path.
  Future<Map<String, dynamic>> refresh({
    required String accessToken,
    required String refreshToken,
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

  /// GET /api/auth/user — basic profile. Throws on non-200.
  Future<CertiliaUser> fetchUserInfo(String accessToken) async {
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

  /// GET /api/user/extended-info — full profile.
  ///
  /// Returns null on 401/502 to let callers decide whether to refresh the
  /// token and retry. Throws on other non-200 statuses.
  Future<CertiliaExtendedInfo?> fetchExtendedInfo(String accessToken) async {
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

  void close() => _httpClient.close();

  CertiliaNetworkException _timeout(String op) => CertiliaNetworkException(
        message: '$op request timed out',
        statusCode: 408,
        details: 'Request timed out',
      );
}
