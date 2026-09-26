import 'package:flutter/material.dart';
import 'package:flutter_certilia/flutter_certilia.dart';
// ignore: implementation_imports
import 'package:flutter_certilia/src/certilia_stateful_wrapper.dart';

import 'widgets/login_view.dart';
import 'widgets/authenticated_view.dart';
import 'models/auth_state.dart';
import 'theme/certilia_theme.dart';

/// Certilia login screen and signed-in view in one widget.
///
/// It keeps the authentication state itself and switches between the login
/// view and the signed-in view without navigation, so an app can use it as
/// its home screen.
///
/// Usage:
/// ```dart
/// CertiliaAuthWidget(
///   serverUrl: 'https://your-backend-server.com',
///   onThemeToggle: () => toggleTheme(),
/// )
/// ```
class CertiliaAuthWidget extends StatefulWidget {
  final String serverUrl;

  /// See `CertiliaConfig.callbackUrl`. Required on web; null on mobile keeps
  /// the in-app WebView flow.
  final String? callbackUrl;

  /// Certilia client used without the proxy; see `CertiliaDirectClient`.
  final CertiliaDirectClient? direct;
  final List<String> scopes;
  final VoidCallback? onThemeToggle;
  final bool enableLogging;

  const CertiliaAuthWidget({
    super.key,
    required this.serverUrl,
    this.callbackUrl,
    this.direct,
    this.scopes = const ['openid', 'profile', 'eid', 'email', 'offline_access'],
    this.onThemeToggle,
    this.enableLogging = false,
  });

  @override
  State<CertiliaAuthWidget> createState() => _CertiliaAuthWidgetState();
}

class _CertiliaAuthWidgetState extends State<CertiliaAuthWidget> {
  // Authentication state
  AuthState _authState = AuthState.initial;
  CertiliaUser? _user;
  CertiliaExtendedInfo? _extendedInfo;
  String? _errorMessage;

  // UI state
  bool _isEnglish = false;
  bool _isLoadingExtendedInfo = false;

  /// SDK client, created once so the login button can call authenticate()
  /// synchronously. On web the SDK must open its popup while the browser is
  /// still handling the tap; Safari blocks window.open after an await.
  dynamic _certilia;

  @override
  void initState() {
    super.initState();
    debugPrint('🏁 [CertiliaAuthWidget] initState called');
    CertiliaSDK.initialize(
      serverUrl: widget.serverUrl,
      callbackUrl: widget.callbackUrl,
      direct: widget.direct,
      scopes: widget.scopes,
      enableLogging: widget.enableLogging,
    ).then((client) => _certilia = client, onError: (Object e) {
      // A configuration error (e.g. direct mode without an https
      // callbackUrl). Show it now; the login button retries initialize().
      debugPrint('❌ [CertiliaAuthWidget] SDK initialization failed: $e');
      if (!mounted) return;
      setState(() => _errorMessage = e.toString());
    });
    _checkStoredAuthentication();
  }

  /// Check if user has stored authentication and load it
  Future<void> _checkStoredAuthentication() async {
    debugPrint('🔍 [CertiliaAuthWidget] Checking stored authentication...');
    setState(() {
      _authState = AuthState.checking;
    });

    try {
      final hasToken = await CertiliaStatefulWrapper.hasValidStoredToken();
      debugPrint('📋 [CertiliaAuthWidget] Has valid token: $hasToken');

      if (hasToken) {
        final storedUser = await CertiliaStatefulWrapper.getStoredUser();
        if (storedUser != null) {
          setState(() {
            _user = storedUser;
            _authState = AuthState.authenticated;
          });

          // Load extended info in background
          _loadExtendedInfo();
        } else {
          setState(() {
            _authState = AuthState.unauthenticated;
          });
        }
      } else {
        setState(() {
          _authState = AuthState.unauthenticated;
        });
      }
    } catch (e) {
      debugPrint('Error checking stored auth: $e');
      setState(() {
        _authState = AuthState.unauthenticated;
      });
    }
  }

  /// Authenticate user
  Future<void> _authenticate() async {
    debugPrint('🚀 [CertiliaAuthWidget] Starting authentication...');
    debugPrint('📊 [CertiliaAuthWidget] Current state before: $_authState');
    setState(() {
      _authState = AuthState.authenticating;
      _errorMessage = null;
    });
    debugPrint('📊 [CertiliaAuthWidget] State changed to: $_authState');

    try {
      // Call authenticate() before any await (see _certilia).
      var certilia = _certilia;
      if (certilia == null) {
        certilia = await CertiliaSDK.initialize(
          serverUrl: widget.serverUrl,
          callbackUrl: widget.callbackUrl,
        direct: widget.direct,
          scopes: widget.scopes,
          enableLogging: widget.enableLogging,
        );
        if (!mounted) return;
      }
      debugPrint('🔐 [CertiliaAuthWidget] Calling authenticate...');
      final user = await certilia.authenticate(context);

      debugPrint('✅ [CertiliaAuthWidget] Authentication returned! User: ${user.fullName}');

      if (!mounted) {
        debugPrint('⚠️ [CertiliaAuthWidget] Widget not mounted after authentication');
        return;
      }

      debugPrint('📝 [CertiliaAuthWidget] Setting state to authenticated...');

      // Store user immediately
      _user = user;

      // Use post-frame callback to ensure UI updates after WebView closes
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          debugPrint('🔄 [CertiliaAuthWidget] Post-frame callback - updating state...');
          debugPrint('🔄 [CertiliaAuthWidget] User stored: ${_user?.fullName}');
          setState(() {
            _authState = AuthState.authenticated;
          });
          debugPrint('🎯 [CertiliaAuthWidget] State updated! AuthState: $_authState, User: ${_user?.fullName}');

          // Load extended info after state is updated
          _loadExtendedInfo();
        }
      });

    } on CertiliaAuthenticationException catch (e) {
      debugPrint('❌ [CertiliaAuthWidget] Authentication exception: ${e.message}');
      if (!mounted) return;

      // Only show error if not cancelled
      if (!e.message.toLowerCase().contains('cancel') &&
          !e.message.toLowerCase().contains('dismissed')) {
        setState(() {
          // Show the SDK's reason (e.g. a blocked popup) so the failure can
          // be diagnosed without a debugger.
          _errorMessage = _isEnglish
            ? 'Authentication failed: ${e.message}'
            : 'Prijava neuspješna: ${e.message}';
          _authState = AuthState.unauthenticated;
        });
      } else {
        debugPrint('🔙 [CertiliaAuthWidget] User cancelled authentication');
        setState(() {
          _authState = AuthState.unauthenticated;
          _errorMessage = null; // Clear any previous errors
        });
      }
    } catch (e) {
      debugPrint('❌ [CertiliaAuthWidget] Unexpected error: $e');
      if (!mounted) return;

      setState(() {
        _errorMessage = _isEnglish
          ? 'An error occurred. Please try again.'
          : 'Dogodila se greška. Pokušajte ponovno.';
        _authState = AuthState.unauthenticated;
      });
    }
  }

  /// Load extended user info
  Future<void> _loadExtendedInfo() async {
    setState(() {
      _isLoadingExtendedInfo = true;
    });

    try {
      // Get the stored access token
      final accessToken = await CertiliaStatefulWrapper.getStoredAccessToken();
      if (accessToken == null) {
        debugPrint('No access token available for extended info');
        setState(() {
          _isLoadingExtendedInfo = false;
        });
        return;
      }

      // A new SDK instance; it loads the stored tokens itself.
      final certilia = await CertiliaSDK.initialize(
        serverUrl: widget.serverUrl,
        callbackUrl: widget.callbackUrl,
        direct: widget.direct,
        scopes: widget.scopes,
        enableLogging: widget.enableLogging,
      );

      CertiliaExtendedInfo? extendedInfo;

      // Try to get extended info using the appropriate client
      if (certilia is CertiliaStatefulWrapper) {
        extendedInfo = await certilia.getExtendedUserInfo();
      } else {
        // For web client, call the method directly
        try {
          extendedInfo = await certilia.getExtendedUserInfo();
        } catch (e) {
          debugPrint('Extended info not available on this platform: $e');
        }
      }

      if (!mounted) return;

      setState(() {
        _extendedInfo = extendedInfo;
        _isLoadingExtendedInfo = false;
      });
    } catch (e) {
      debugPrint('Error loading extended info: $e');
      if (!mounted) return;

      setState(() {
        _isLoadingExtendedInfo = false;
      });
    }
  }

  /// Refresh token
  Future<void> _refreshToken() async {
    try {
      final certilia = await CertiliaSDK.initialize(
        serverUrl: widget.serverUrl,
        callbackUrl: widget.callbackUrl,
        direct: widget.direct,
        scopes: widget.scopes,
        enableLogging: widget.enableLogging,
      );

      // Try to refresh token using the appropriate client
      if (certilia is CertiliaStatefulWrapper) {
        await certilia.refreshToken();
      } else {
        // For web client, call the refresh method
        try {
          await certilia.refreshToken();
        } catch (e) {
          debugPrint('Refresh token not available on this platform: $e');
          throw e;
        }
      }

      if (!mounted) return;

      // Reload extended info with new token
      _loadExtendedInfo();

      // Show success
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEnglish ? 'Token refreshed successfully' : 'Token uspješno osvježen'),
            backgroundColor: CertiliaTheme.successGreen,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error refreshing token: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEnglish ? 'Failed to refresh token' : 'Osvježavanje tokena neuspješno'),
            backgroundColor: CertiliaTheme.errorRed,
          ),
        );
      }
    }
  }

  /// Logout user
  Future<void> _logout() async {
    await CertiliaStatefulWrapper.clearStoredData();

    setState(() {
      _user = null;
      _extendedInfo = null;
      _authState = AuthState.unauthenticated;
      _errorMessage = null;
    });
  }

  /// Toggle language
  void _toggleLanguage() {
    setState(() {
      _isEnglish = !_isEnglish;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    debugPrint('🔧 [CertiliaAuthWidget] Building - AuthState: $_authState, User: ${_user?.fullName}');

    return Scaffold(
      backgroundColor: CertiliaTheme.backgroundColor(isDark),
      body: _buildBody(isDark),
    );
  }

  Widget _buildBody(bool isDark) {
    debugPrint('🎨 [CertiliaAuthWidget] Building body for state: $_authState');
    switch (_authState) {
      case AuthState.initial:
      case AuthState.checking:
        return Center(
          child: CircularProgressIndicator(
            color: CertiliaTheme.primaryBlue,
          ),
        );

      case AuthState.authenticating:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                color: CertiliaTheme.primaryBlue,
              ),
              const SizedBox(height: 20),
              Text(
                _isEnglish ? 'Authenticating...' : 'Prijavljivanje...',
                style: CertiliaTextStyles.bodyLarge(isDark),
              ),
            ],
          ),
        );

      case AuthState.unauthenticated:
        return LoginView(
          isDark: isDark,
          isEnglish: _isEnglish,
          errorMessage: _errorMessage,
          onAuthenticate: _authenticate,
          onToggleLanguage: _toggleLanguage,
          onThemeToggle: widget.onThemeToggle,
        );

      case AuthState.authenticated:
        return AuthenticatedView(
          isDark: isDark,
          isEnglish: _isEnglish,
          user: _user!,
          extendedInfo: _extendedInfo,
          isLoadingExtendedInfo: _isLoadingExtendedInfo,
          onLogout: _logout,
          onToggleLanguage: _toggleLanguage,
          onThemeToggle: widget.onThemeToggle,
        );
    }
  }
}