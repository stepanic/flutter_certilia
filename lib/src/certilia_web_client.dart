// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
// ignore: deprecated_member_use
import 'package:web/web.dart' as web;

import 'package:flutter/material.dart';

import 'exceptions/certilia_exception.dart';
import 'models/certilia_config.dart';
import 'models/certilia_extended_info.dart';
import 'models/certilia_token.dart';
import 'models/certilia_user.dart';
import 'oauth_callback.dart';
import 'refresh_errors.dart';
import 'services/certilia_logger.dart';
import 'services/auth_backend_factory.dart';
import 'services/certilia_auth_backend.dart';
import 'services/proxy_auth_service.dart';
import 'services/token_storage_service.dart';

/// Web-specific client for Certilia OAuth authentication.
///
/// Opens a popup window for the auth flow. How the result gets back depends
/// on [CertiliaConfig.callbackUrl]:
/// - `null`: Certilia redirects to the proxy's `/api/auth/callback` and the
///   app polls the proxy until the code arrives.
/// - a page on the app's own origin: Certilia redirects there, and the page
///   (see `example/web/certilia_callback.html`) posts the callback URL on
///   the `certilia_auth` BroadcastChannel and through a `storage` event.
///   Both reach every same-origin document even when
///   `Cross-Origin-Opener-Policy` has cut the popup off from its opener,
///   which is why neither flow uses `window.opener` or `postMessage`.
///
/// HTTP requests go through the [CertiliaAuthBackend] and the saved token
/// through [TokenStorageService]. This class opens and closes the popup and
/// holds the current token in memory.
class CertiliaWebClient {
  final CertiliaConfig config;
  final String serverUrl;
  final CertiliaAuthBackend _backend;
  final TokenStorageService _tokenStorage;
  final CertiliaLogger _logger;

  CertiliaToken? _currentToken;

  /// Completes when the constructor has loaded the saved token. The public
  /// async methods await it, so they do not report "not authenticated"
  /// before storage has been read.
  late final Future<void> _ready;

  static const Duration _pollingInterval = Duration(seconds: 2);
  static const Duration _popupCheckInterval = Duration(seconds: 1);
  static const Duration _pollingTimeout = Duration(minutes: 5);
  static const int _popupWidth = 500;
  static const int _popupHeight = 700;

  /// BroadcastChannel name and localStorage key the callback page writes to.
  static const String callbackChannel = 'certilia_auth';
  static const String callbackStorageKey = 'certilia_auth_result';

  CertiliaWebClient({
    required this.config,
    required this.serverUrl,
    CertiliaAuthBackend? backend,
    TokenStorageService? tokenStorage,
  })  : _logger = CertiliaLogger(
          componentName: 'CertiliaWebClient',
          enableLogging: config.enableLogging,
        ),
        _backend = backend ??
            createAuthBackend(
              config: config,
              serverUrl: serverUrl,
              componentName: 'CertiliaWebClient',
            ),
        _tokenStorage = tokenStorage ?? TokenStorageService() {
    config.validate();
    if (config.callbackUrl == null && _backend is! ProxyAuthService) {
      throw ArgumentError(
          'Without a callbackUrl the web client polls certilia-server, '
          'so its backend must be a ProxyAuthService');
    }
    _ready = _initializeTokens();
  }

  Future<void> _initializeTokens() async {
    _currentToken = await _tokenStorage.loadToken();
    if (_currentToken != null) {
      _logger.log(_currentToken!.isExpired
          ? 'Loaded saved token (expired; caller decides)'
          : 'Loaded saved authentication token');
    }
  }

  /// Runs the login in a popup (see the class comment for the two ways the
  /// result comes back), saves the tokens and returns the user.
  Future<CertiliaUser> authenticate(BuildContext context) async {
    // Safari (and every browser on iOS) lets a page open a window only while
    // it is still handling the user's tap; a network round trip ends that,
    // and window.open then returns null. So the popup opens blank here,
    // before the first await, and goes to Certilia once the proxy has
    // returned the authorization URL. Callers must call authenticate()
    // directly from the tap handler, without awaiting network I/O first.
    // (Chrome and Firefox allow popups for a few seconds after a click,
    // which is why opening after the proxy call works there.)
    final web.Window popup;
    try {
      popup = _openPopup();
    } catch (e) {
      _logger.log('Authentication failed: $e');
      rethrow;
    }
    try {
      await _ready;
      _logger.log('Starting web authentication flow');

      final String code;
      final Map<String, dynamic> authData;
      if (config.callbackUrl != null) {
        authData = await _backend.initialize(redirectUri: config.callbackUrl);
        final callback = await _openAuthPopupWithCallbackPage(
          popup: popup,
          authorizationUrl: authData['authorization_url'] as String,
          state: authData['state'] as String,
        );
        code = codeFromCallback(
          callback,
          expectedState: authData['state'] as String,
        );
      } else {
        // Polling needs the proxy; the constructor rejects any other
        // backend without a callbackUrl.
        final proxy = _backend as ProxyAuthService;
        authData = await proxy.initialize();
        final polling = await proxy.startPollingSession(
          state: authData['state'] as String,
          sessionId: authData['session_id'] as String,
        );
        final polledCode = await _openAuthPopupWithPolling(
          proxy: proxy,
          popup: popup,
          authorizationUrl: authData['authorization_url'] as String,
          pollingId: polling['polling_id'] as String,
        );
        if (polledCode == null) {
          throw const CertiliaAuthenticationException(
            message: 'Authentication was cancelled',
          );
        }
        code = polledCode;
      }

      final tokenData = await _backend.exchange(
        code: code,
        state: authData['state'] as String,
        sessionId: authData['session_id'] as String,
      );

      _currentToken = _tokenFromResponse(tokenData);
      await _tokenStorage.saveToken(_currentToken!);

      final user = tokenData['user'] != null
          ? CertiliaUser.fromJson(tokenData['user'] as Map<String, dynamic>)
          : await _backend.fetchUserInfo(
              _currentToken!.accessToken,
              idToken: _currentToken!.idToken,
            );

      _logger.log('Authentication successful for user: ${user.sub}');
      return user;
    } catch (e) {
      _logger.log('Authentication failed: $e');
      _closePopup(popup);
      if (e is CertiliaException) rethrow;
      throw CertiliaAuthenticationException(
        message: 'Authentication failed',
        details: e.toString(),
      );
    }
  }

  /// Opens an empty, centred popup. Must run while the browser is still
  /// handling the user's tap; see [authenticate].
  web.Window _openPopup() {
    final left = (web.window.screen.width - _popupWidth) ~/ 2;
    final top = (web.window.screen.height - _popupHeight) ~/ 2;
    final popup = web.window.open(
      '',
      'certilia_auth',
      'width=$_popupWidth,height=$_popupHeight,left=$left,top=$top',
    );
    if (popup == null) {
      throw const CertiliaAuthenticationException(
        message: 'Popup blocked. Allow popups for this site and try again.',
        code: 'popup_blocked',
      );
    }
    return popup;
  }

  /// Sends [popup] to [authorizationUrl]. Returns false when the user has
  /// already closed it, which happens while the popup is still blank during
  /// the proxy round trip. Until the popup leaves the app's origin,
  /// `popup.closed` is reliable even under COOP, and afterwards
  /// [_watchForUserClose] cannot tell this close from COOP cutting the
  /// reference, so it has to be caught here.
  bool _sendPopup(web.Window popup, String authorizationUrl) {
    if (popup.closed) {
      _logger.log('Popup closed before it was sent to Certilia');
      return false;
    }
    popup.location.href = authorizationUrl;
    return true;
  }

  void _closePopup(web.Window popup) {
    try {
      popup.close();
    } catch (_) {}
  }

  /// Calls [onUserClosed] when the user closes [popup].
  ///
  /// `popup.closed` alone cannot tell: when the app page sends
  /// `Cross-Origin-Opener-Policy: same-origin`, the browser cuts the app off
  /// from the popup as soon as it navigates to Certilia, and `closed` reads
  /// true while the popup is still open. Without COOP, reading
  /// `popup.location.href` throws while the popup shows Certilia's
  /// (cross-origin) page. Only after seeing that do we know the reference
  /// is intact, so only then does a later `closed` mean the user closed it.
  /// Otherwise the flow relies on its result channel and timeout.
  Timer _watchForUserClose(web.Window popup, void Function() onUserClosed) {
    var sawCrossOrigin = false;
    return Timer.periodic(_popupCheckInterval, (timer) {
      if (!popup.closed) {
        try {
          popup.location.href;
        } catch (_) {
          sawCrossOrigin = true;
        }
        return;
      }
      timer.cancel();
      if (sawCrossOrigin) {
        onUserClosed();
      } else {
        _logger.log('popup.closed without seeing the popup on Certilia '
            '(COOP cut the reference, or it closed before loading); '
            'waiting for the result or the timeout');
      }
    });
  }

  /// Sends [popup] to Certilia and waits for the callback page on the app's
  /// origin to report the callback URL. Returns null on timeout or when the
  /// user closes the popup.
  Future<Uri?> _openAuthPopupWithCallbackPage({
    required web.Window popup,
    required String authorizationUrl,
    required String state,
  }) async {
    final completer = Completer<Uri?>();
    _logger.log('Sending popup to Certilia, callback page: ${config.callbackUrl}');
    if (!_sendPopup(popup, authorizationUrl)) return null;
    final expected = Uri.parse(config.callbackUrl!);

    // Accept only a callback for this login: same callback page, our state,
    // written in the last 10 minutes. Results of another tab's login are
    // ignored. The accepted result is removed from localStorage.
    void onPayload(String? payload, String via) {
      if (payload == null || completer.isCompleted) return;
      final Uri url;
      try {
        final decoded = jsonDecode(payload) as Map<String, dynamic>;
        final at = decoded['at'] as int?;
        if (at != null &&
            DateTime.now().millisecondsSinceEpoch - at > 10 * 60 * 1000) {
          return;
        }
        url = Uri.parse(decoded['url'] as String);
      } catch (_) {
        return;
      }
      // Compared part by part: Uri.origin throws for non-http(s) URLs, and
      // anything on the channel can post one.
      if (url.scheme != expected.scheme ||
          url.host != expected.host ||
          url.port != expected.port ||
          url.path != expected.path) {
        return;
      }
      if (url.queryParameters['state'] != state) return;
      _logger.log('Callback page reported the result via $via');
      try {
        web.window.localStorage.removeItem(callbackStorageKey);
      } catch (_) {}
      completer.complete(url);
    }

    final channel = web.BroadcastChannel(callbackChannel);
    channel.onmessage = ((web.MessageEvent e) {
      onPayload((e.data as JSString?)?.toDart, 'BroadcastChannel');
    }).toJS;

    final storageListener = ((web.StorageEvent e) {
      if (e.key == callbackStorageKey) onPayload(e.newValue, 'storage event');
    }).toJS;
    web.window.addEventListener('storage', storageListener);

    // Mobile browsers suspend background tabs, and while the user approves
    // the login in the Certilia app this tab is in the background. Events
    // sent to it then can be lost, so also read the entry the callback page
    // leaves in localStorage. Timers resume when the tab does.
    final storageCheckTimer = Timer.periodic(_popupCheckInterval, (_) {
      try {
        onPayload(
          web.window.localStorage.getItem(callbackStorageKey),
          'localStorage check',
        );
      } catch (_) {}
    });

    final popupCheckTimer = _watchForUserClose(popup, () {
      // The callback page closes the popup itself right after posting, so
      // give the message a moment to arrive before calling it a cancel.
      Timer(const Duration(seconds: 2), () {
        if (!completer.isCompleted) {
          _logger.log('Popup closed without a callback');
          completer.complete(null);
        }
      });
    });
    final timeoutTimer = Timer(_pollingTimeout, () {
      if (!completer.isCompleted) {
        _logger.log('Timed out waiting for the callback page');
        completer.complete(null);
      }
    });

    try {
      return await completer.future;
    } finally {
      popupCheckTimer.cancel();
      storageCheckTimer.cancel();
      timeoutTimer.cancel();
      channel.close();
      web.window.removeEventListener('storage', storageListener);
      _closePopup(popup);
    }
  }

  Future<String?> _openAuthPopupWithPolling({
    required ProxyAuthService proxy,
    required web.Window popup,
    required String authorizationUrl,
    required String pollingId,
  }) async {
    final completer = Completer<String?>();

    _logger.log('Sending popup to Certilia, polling id: $pollingId');
    if (!_sendPopup(popup, authorizationUrl)) return null;

    Timer? pollTimer;
    Timer? popupCheckTimer;
    Timer? timeoutTimer;
    var active = true;

    void cleanup() {
      active = false;
      pollTimer?.cancel();
      popupCheckTimer?.cancel();
      timeoutTimer?.cancel();
    }

    void closePopupSoon() {
      Timer(const Duration(milliseconds: 100), () {
        try {
          popup.close();
        } catch (_) {}
      });
    }

    timeoutTimer = Timer(_pollingTimeout, () {
      if (completer.isCompleted) return;
      _logger.log('Polling timeout reached');
      cleanup();
      completer.complete(null);
      closePopupSoon();
    });

    pollTimer = Timer.periodic(_pollingInterval, (_) async {
      if (!active) return;
      try {
        final data = await proxy.pollStatus(pollingId);
        if (data == null) {
          // The proxy has no such polling session: it expired or never
          // existed.
          cleanup();
          if (!completer.isCompleted) completer.complete(null);
          return;
        }
        final status = data['status'];
        if (status == 'completed' && data['result'] != null) {
          final code = (data['result'] as Map<String, dynamic>)['code'];
          _logger.log('Auth completed via polling');
          cleanup();
          if (!completer.isCompleted) completer.complete(code as String?);
          closePopupSoon();
        } else if (status == 'error') {
          _logger.log('Server reported auth error: ${data['error']}');
          cleanup();
          if (!completer.isCompleted) completer.complete(null);
          closePopupSoon();
        }
      } catch (e) {
        _logger.log('Polling error: $e');
      }
    });

    popupCheckTimer = _watchForUserClose(popup, () {
      // Give polling one more window: the server callback may still be in
      // flight.
      Timer(const Duration(seconds: 3), () {
        if (!completer.isCompleted && active) {
          _logger.log('Popup closed without polling result');
          cleanup();
          completer.complete(null);
        }
      });
    });

    return completer.future;
  }

  bool get isAuthenticated =>
      _currentToken != null && !_currentToken!.isExpired;

  Future<bool> checkAuthenticationStatus() async {
    await _ready;
    return isAuthenticated;
  }

  Future<CertiliaUser?> getCurrentUser() async {
    try {
      await _ready;
      if (_currentToken == null) return null;

      if (_currentToken!.isExpired) {
        if (_currentToken!.refreshToken == null) return null;
        await refreshToken();
      }

      return await _backend.fetchUserInfo(
        _currentToken!.accessToken,
        idToken: _currentToken!.idToken,
      );
    } catch (e) {
      _logger.log('Failed to get current user: $e');
      return null;
    }
  }

  Future<void> refreshToken() async {
    if (_currentToken?.refreshToken == null) {
      throw const CertiliaAuthenticationException(
        message: 'No refresh token available',
      );
    }
    try {
      _logger.log('Refreshing token');
      final tokenData = await _backend.refresh(
        accessToken: _currentToken!.accessToken,
        refreshToken: _currentToken!.refreshToken!,
        idToken: _currentToken!.idToken,
      );
      _currentToken = _tokenFromResponse(
        tokenData,
        fallbackRefreshToken: _currentToken!.refreshToken,
        fallbackIdToken: _currentToken!.idToken,
      );
      await _tokenStorage.saveToken(_currentToken!);
      _logger.log('Token refreshed successfully');
    } catch (e) {
      _logger.log('Token refresh failed: $e');
      if (e is CertiliaException) rethrow;
      // Not a refusal (see refreshWasRefused): the session stays.
      throw CertiliaException(
        message: 'Failed to refresh token',
        details: e.toString(),
      );
    }
  }

  Future<void> logout() async {
    await _ready;
    _logger.log('Logging out user');
    _currentToken = null;
    await _tokenStorage.deleteToken();
  }

  /// Returns extended user info. Refreshes once on 401/502 and logs out
  /// when the refresh is refused (see `refreshWasRefused`); other refresh
  /// failures are rethrown and keep the session.
  Future<CertiliaExtendedInfo?> getExtendedUserInfo() async {
    await _ready;
    if (_currentToken == null || _currentToken!.isExpired) {
      _logger.log('No valid token for extended info');
      return null;
    }

    final info = await _backend.fetchExtendedInfo(
      _currentToken!.accessToken,
      idToken: _currentToken!.idToken,
    );
    if (info != null) return info;

    // The backend returned null for a 401/502: refresh once and retry.
    if (_currentToken!.refreshToken == null) {
      await logout();
      return null;
    }
    try {
      await refreshToken();
    } catch (e) {
      if (!refreshWasRefused(e)) rethrow;
      _logger.log('Refresh refused, clearing authentication: $e');
      await logout();
      return null;
    }
    return await _backend.fetchExtendedInfo(
      _currentToken!.accessToken,
      idToken: _currentToken!.idToken,
    );
  }

  String? get currentAccessToken => _currentToken?.accessToken;
  String? get currentRefreshToken => _currentToken?.refreshToken;
  String? get currentIdToken => _currentToken?.idToken;
  DateTime? get tokenExpiry => _currentToken?.expiresAt;

  void dispose() => _backend.close();

  CertiliaToken _tokenFromResponse(
    Map<String, dynamic> data, {
    String? fallbackRefreshToken,
    String? fallbackIdToken,
  }) {
    final expiresIn = data['expiresIn'];
    return CertiliaToken(
      accessToken: data['accessToken'] as String,
      refreshToken:
          (data['refreshToken'] as String?) ?? fallbackRefreshToken,
      idToken: (data['idToken'] as String?) ?? fallbackIdToken,
      expiresAt: expiresIn != null
          ? DateTime.now().add(Duration(seconds: expiresIn as int))
          : null,
      tokenType: (data['tokenType'] as String?) ?? 'Bearer',
    );
  }
}

/// The client type on web; `certilia_webview_client.dart` defines the same
/// name for mobile and desktop.
typedef CertiliaPlatformClient = CertiliaWebClient;
