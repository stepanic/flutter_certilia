import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_certilia/flutter_certilia.dart';

void main() {
  runApp(const MyApp());
}

/// Certilia official theme colors and styling
class CertiliaTheme {
  // Primary Colors
  static const Color primaryBlue = Color(0xFF2563EB);
  static const Color primaryBlueDark = Color(0xFF1E40AF);
  static const Color primaryBlueLight = Color(0xFF3B82F6);

  // Light Theme Colors
  static const Color lightBackground = Color(0xFFF8FAFC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceGray = Color(0xFFF3F4F6);
  static const Color lightTextPrimary = Color(0xFF1F2937);
  static const Color lightTextSecondary = Color(0xFF6B7280);
  static const Color lightTextTertiary = Color(0xFF9CA3AF);
  static const Color lightBorder = Color(0xFFE5E7EB);
  static const Color lightDivider = Color(0xFFF3F4F6);

  // Dark Theme Colors
  static const Color darkBackground = Color(0xFF0F172A);
  static const Color darkSurface = Color(0xFF1E293B);
  static const Color darkSurfaceGray = Color(0xFF334155);
  static const Color darkTextPrimary = Color(0xFFF1F5F9);
  static const Color darkTextSecondary = Color(0xFFCBD5E1);
  static const Color darkTextTertiary = Color(0xFF94A3B8);
  static const Color darkBorder = Color(0xFF334155);
  static const Color darkDivider = Color(0xFF1E293B);

  // Status Colors (same for both themes)
  static const Color successGreen = Color(0xFF10B981);
  static const Color warningOrange = Color(0xFFF59E0B);
  static const Color errorRed = Color(0xFFEF4444);

  // Spacing
  static const double spaceXS = 8.0;
  static const double spaceSM = 12.0;
  static const double spaceMD = 16.0;
  static const double spaceLG = 24.0;
  static const double spaceXL = 32.0;

  // Border Radius
  static const double radiusSmall = 8.0;
  static const double radiusMedium = 12.0;
  static const double radiusLarge = 16.0;

  // Shadows (context-aware)
  static List<BoxShadow> cardShadow(bool isDark) => [
    BoxShadow(
      color: isDark
        ? Colors.black.withValues(alpha: 0.3)
        : Colors.black.withValues(alpha: 0.05),
      blurRadius: 10,
      offset: const Offset(0, 2),
    ),
  ];

  // Helper methods for theme-aware colors
  static Color backgroundColor(bool isDark) =>
    isDark ? darkBackground : lightBackground;

  static Color surfaceColor(bool isDark) =>
    isDark ? darkSurface : lightSurface;

  static Color surfaceGrayColor(bool isDark) =>
    isDark ? darkSurfaceGray : lightSurfaceGray;

  static Color textPrimaryColor(bool isDark) =>
    isDark ? darkTextPrimary : lightTextPrimary;

  static Color textSecondaryColor(bool isDark) =>
    isDark ? darkTextSecondary : lightTextSecondary;

  static Color textTertiaryColor(bool isDark) =>
    isDark ? darkTextTertiary : lightTextTertiary;

  static Color borderColor(bool isDark) =>
    isDark ? darkBorder : lightBorder;

  static Color dividerColor(bool isDark) =>
    isDark ? darkDivider : lightDivider;
}

/// Certilia text styles (theme-aware)
class CertiliaTextStyles {
  // Headings
  static TextStyle heading(bool isDark) => TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.5,
    color: CertiliaTheme.textPrimaryColor(isDark),
  );

  static TextStyle subheading(bool isDark) => TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.5,
    color: CertiliaTheme.textPrimaryColor(isDark),
  );

  // Body Text
  static TextStyle bodyLarge(bool isDark) => TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: CertiliaTheme.textPrimaryColor(isDark),
  );

  static TextStyle bodyMedium(bool isDark) => TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: CertiliaTheme.textPrimaryColor(isDark),
  );

  static TextStyle bodySmall(bool isDark) => TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: CertiliaTheme.textSecondaryColor(isDark),
  );

  // Labels
  static TextStyle label(bool isDark) => TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: CertiliaTheme.textSecondaryColor(isDark),
  );

  static TextStyle labelSmall(bool isDark) => TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: CertiliaTheme.textSecondaryColor(isDark),
  );

  // Buttons
  static const TextStyle button = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // Default to dark theme
  ThemeMode _themeMode = ThemeMode.dark;

  void _toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.light
        ? ThemeMode.dark
        : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Certilia SDK Example',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      // Light Theme
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        primaryColor: CertiliaTheme.primaryBlue,
        scaffoldBackgroundColor: CertiliaTheme.lightBackground,
        colorScheme: const ColorScheme.light(
          primary: CertiliaTheme.primaryBlue,
          secondary: CertiliaTheme.successGreen,
          error: CertiliaTheme.errorRed,
          surface: CertiliaTheme.lightSurface,
        ),
      ),
      // Dark Theme
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        primaryColor: CertiliaTheme.primaryBlue,
        scaffoldBackgroundColor: CertiliaTheme.darkBackground,
        colorScheme: const ColorScheme.dark(
          primary: CertiliaTheme.primaryBlue,
          secondary: CertiliaTheme.successGreen,
          error: CertiliaTheme.errorRed,
          surface: CertiliaTheme.darkSurface,
        ),
      ),
      home: HomePage(onThemeToggle: _toggleTheme),
    );
  }
}

class HomePage extends StatefulWidget {
  final VoidCallback onThemeToggle;

  const HomePage({
    super.key,
    required this.onThemeToggle,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // State variables
  dynamic _certilia;
  CertiliaUser? _user;
  CertiliaExtendedInfo? _extendedInfo;
  bool _isLoading = false;
  bool _isInitialized = false;
  String? _error;
  DateTime? _tokenExpiryTime;
  bool _isEnglish = false;

  @override
  void initState() {
    super.initState();
    _initializeSDK();
  }

  @override
  void dispose() {
    if (_isInitialized) {
      _certilia.dispose();
    }
    super.dispose();
  }

  /// Initialize the Certilia SDK with backend server configuration
  Future<void> _initializeSDK() async {
    debugPrint('Initializing Certilia SDK...');
    setState(() => _isLoading = true);

    try {
      _certilia = await CertiliaSDKSimple.initialize(
        clientId: '991dffbb1cdd4d51423e1a5de323f13b15256c63',
        serverUrl: 'https://uniformly-credible-opossum.ngrok-free.app',
        scopes: ['openid', 'profile', 'eid', 'email', 'offline_access'],
        enableLogging: true,
        sessionTimeout: 3600000,
      );

      debugPrint('SDK initialized successfully');

      setState(() {
        _isInitialized = true;
        _isLoading = false;
      });

      // Check if user is already authenticated (from saved tokens)
      // Use a small delay to ensure UI is ready
      Future.delayed(const Duration(milliseconds: 100), () async {
        if (!mounted) return;
        await _checkAuthStatus();
      });
    } catch (e) {
      debugPrint('Failed to initialize SDK: $e');
      setState(() {
        _isLoading = false;
        _error = 'Failed to initialize SDK: $e';
      });
    }
  }

  /// Check current authentication status
  Future<void> _checkAuthStatus() async {
    if (!_isInitialized) return;

    debugPrint('Checking authentication status...');
    final isAuth = await _certilia.checkAuthenticationStatus();
    debugPrint('Is authenticated: $isAuth');

    if (isAuth) {
      try {
        final user = await _certilia.getCurrentUser();
        debugPrint('Current user: ${user?.sub}');

        if (!mounted) return;

        setState(() {
          _user = user;
          // If we have a user, we should clear any error
          if (user != null) {
            _error = null;
          }
        });

        if (user != null) {
          // Try to get extended info
          await _getExtendedInfo(showLoading: false);
        }
      } catch (e) {
        debugPrint('Failed to get current user: $e');
        // Only clear user data if we're truly not authenticated
        if (!mounted) return;

        // Check again if authenticated
        final stillAuth = await _certilia.checkAuthenticationStatus();
        if (!stillAuth && mounted) {
          setState(() {
            _user = null;
            _extendedInfo = null;
            _tokenExpiryTime = null;
            _error = _isEnglish
                ? 'Session expired. Please sign in again.'
                : 'Sesija je istekla. Molimo prijavite se ponovno.';
          });
        }
      }
    } else {
      // Not authenticated - clear user data
      if (mounted) {
        setState(() {
          _user = null;
          _extendedInfo = null;
          _tokenExpiryTime = null;
        });
      }
    }
  }

  /// Authenticate user with Certilia
  Future<void> _authenticate() async {
    if (!_isInitialized) {
      _showSnackBar(
        _isEnglish
          ? 'Please wait for SDK initialization'
          : 'Molimo pričekajte inicijalizaciju SDK-a'
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
      // Clear any existing data before new authentication
      _user = null;
      _extendedInfo = null;
      _tokenExpiryTime = null;
    });

    try {
      final user = await _certilia.authenticate(context);
      if (!mounted) return;

      setState(() {
        _user = user;
        _isLoading = false;
        // Get initial token expiry
        _tokenExpiryTime = _certilia.tokenExpiry;
      });

      await _getExtendedInfo();
    } on CertiliaAuthenticationException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _isEnglish
          ? 'Authentication failed: ${e.message}'
          : 'Autentifikacija neuspješna: ${e.message}';
        _isLoading = false;
      });
    } on CertiliaNetworkException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _isEnglish
          ? 'Network error: ${e.message}'
          : 'Mrežna greška: ${e.message}';
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _isEnglish
          ? 'Unexpected error: $e'
          : 'Neočekivana greška: $e';
        _isLoading = false;
      });
    }
  }

  /// Get extended user information
  Future<void> _getExtendedInfo({bool showLoading = true}) async {
    if (!mounted || !_isInitialized) return;

    debugPrint('📊 Fetching extended info, showLoading: $showLoading');

    // Only show loading for initial fetch, not for refresh
    if (showLoading) {
      setState(() => _isLoading = true);
    }

    try {
      final extendedInfo = await _certilia.getExtendedUserInfo();
      if (!mounted) return;

      debugPrint('📊 Extended info response: ${extendedInfo != null ? "${extendedInfo.availableFields.length} fields" : "null"}');

      // Check if we're still authenticated
      final isAuthenticated = await _certilia.checkAuthenticationStatus();
      debugPrint('🔐 Authentication status: $isAuthenticated');

      // Only clear data if we're truly not authenticated
      if (!isAuthenticated) {
        debugPrint('❌ Not authenticated, clearing all data');
        setState(() {
          _user = null;
          _extendedInfo = null;
          _tokenExpiryTime = null;
          _isLoading = false;
          _error = _isEnglish
              ? 'Session expired. Please sign in again.'
              : 'Sesija je istekla. Molimo prijavite se ponovno.';
        });
        return;
      }

      // We're authenticated, update with new data or clear if null
      setState(() {
        _extendedInfo = extendedInfo;
        _tokenExpiryTime = extendedInfo?.tokenExpiry ?? _certilia.tokenExpiry;
        _isLoading = false;
      });

      if (extendedInfo != null) {
        debugPrint('✅ Got extended info with ${extendedInfo.availableFields.length} fields');
      } else {
        debugPrint('⚠️ No extended info available');
      }
    } catch (e) {
      debugPrint('Error fetching extended info: $e');
      if (!mounted) return;

      // Don't clear existing data on error - just show error message
      setState(() {
        _error = _isEnglish
          ? 'Failed to refresh extended info: $e'
          : 'Neuspješno osvježavanje proširenih podataka: $e';
        if (showLoading) {
          _isLoading = false;
        }
      });

      // Show error as snackbar instead of clearing data
      _showSnackBar(
        _isEnglish
          ? 'Could not refresh extended info'
          : 'Nije moguće osvježiti proširene podatke',
        isSuccess: false,
      );
    }
  }

  /// Refresh authentication token
  Future<void> _refreshToken() async {
    if (!_isInitialized) return;

    debugPrint('🔄 Starting token refresh...');

    setState(() {
      _isLoading = true;
      _error = null;
      // Clear extended info to get fresh data after refresh
      _extendedInfo = null;
    });

    try {
      await _certilia.refreshToken();
      debugPrint('✅ Token refreshed successfully');

      // Update token expiry immediately after refresh
      setState(() {
        _isLoading = false;
        // Update token expiry from refreshed token
        _tokenExpiryTime = _certilia.tokenExpiry;
      });

      debugPrint('⏰ New token expiry: $_tokenExpiryTime');

      _showSnackBar(
        _isEnglish
          ? 'Token refreshed successfully'
          : 'Token uspješno osvježen',
        isSuccess: true,
      );

      // Fetch fresh user and extended info with new token
      if (_user != null) {
        debugPrint('📊 Fetching fresh user data with new token...');

        // Get fresh user data
        final freshUser = await _certilia.getCurrentUser();
        if (freshUser != null && mounted) {
          setState(() {
            _user = freshUser;
          });
        }

        // Get fresh extended info
        await _getExtendedInfo(showLoading: false);

        debugPrint('📊 After refresh - extended info fields: ${_extendedInfo?.availableFields.length ?? 0}');
        debugPrint('⏰ Token expiry after extended info: $_tokenExpiryTime');
      } else {
        // If we somehow don't have user data, fetch it
        await _checkAuthStatus();
      }
    } catch (e) {
      debugPrint('Token refresh failed: $e');
      setState(() {
        _error = _isEnglish
          ? 'Token refresh failed: $e'
          : 'Osvježavanje tokena neuspješno: $e';
        _isLoading = false;
      });

      // Check if we're still authenticated with old token
      final stillAuth = await _certilia.checkAuthenticationStatus();
      if (!stillAuth && mounted) {
        // Only clear user data if we're truly not authenticated
        setState(() {
          _user = null;
          _extendedInfo = null;
          _tokenExpiryTime = null;
        });
      }
    }
  }

  /// Logout user
  Future<void> _logout() async {
    if (!_isInitialized) return;

    setState(() => _isLoading = true);

    try {
      await _certilia.logout();
      if (!mounted) return;

      setState(() {
        _user = null;
        _extendedInfo = null;
        _isLoading = false;
        _error = null;
        _tokenExpiryTime = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _isEnglish
          ? 'Logout failed: $e'
          : 'Odjava neuspješna: $e';
        _isLoading = false;
      });
    }
  }

  /// Show snackbar notification
  void _showSnackBar(String message, {bool isSuccess = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isSuccess
          ? CertiliaTheme.successGreen
          : CertiliaTheme.errorRed,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Check if token is expiring soon (within 5 minutes)
  bool _isTokenExpiringSoon() {
    if (_tokenExpiryTime == null) return false;
    final timeUntilExpiry = _tokenExpiryTime!.difference(DateTime.now());
    return timeUntilExpiry.inMinutes < 5;
  }

  /// Get human-readable time until token expiry
  String _getTimeUntilExpiry() {
    if (_tokenExpiryTime == null) {
      return _isEnglish ? 'Unknown' : 'Nepoznato';
    }

    final timeUntilExpiry = _tokenExpiryTime!.difference(DateTime.now());

    if (timeUntilExpiry.isNegative) {
      return _isEnglish ? 'Expired' : 'Istekao';
    }

    if (timeUntilExpiry.inDays > 0) {
      return _isEnglish
          ? '${timeUntilExpiry.inDays} days'
          : '${timeUntilExpiry.inDays} ${timeUntilExpiry.inDays == 1 ? 'dan' : 'dana'}';
    } else if (timeUntilExpiry.inHours > 0) {
      return _isEnglish
          ? '${timeUntilExpiry.inHours} hours'
          : '${timeUntilExpiry.inHours} ${timeUntilExpiry.inHours == 1 ? 'sat' : timeUntilExpiry.inHours < 5 ? 'sata' : 'sati'}';
    } else if (timeUntilExpiry.inMinutes > 0) {
      return _isEnglish
          ? '${timeUntilExpiry.inMinutes} minutes'
          : '${timeUntilExpiry.inMinutes} ${timeUntilExpiry.inMinutes == 1 ? 'minuta' : timeUntilExpiry.inMinutes < 5 ? 'minute' : 'minuta'}';
    } else {
      return _isEnglish
          ? '${timeUntilExpiry.inSeconds} seconds'
          : '${timeUntilExpiry.inSeconds} ${timeUntilExpiry.inSeconds == 1 ? 'sekunda' : timeUntilExpiry.inSeconds < 5 ? 'sekunde' : 'sekundi'}';
    }
  }

  /// Format field name from snake_case to Title Case
  String _formatFieldName(String fieldName) {
    return fieldName
        .split('_')
        .map((word) => word.isNotEmpty
            ? '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}'
            : '')
        .join(' ');
  }

  /// Format DateTime to local string
  String _formatDateTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    return '${local.day}.${local.month}.${local.year} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: CertiliaTheme.backgroundColor(isDark),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _isInitialized
                ? (_user != null
                    ? _buildAuthenticatedView()
                    : _buildUnauthenticatedView())
                : _buildLoadingView(),
          ),
        ],
      ),
    );
  }

  /// Build header with logo and language toggle
  Widget _buildHeader() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: CertiliaTheme.spaceLG,
        vertical: CertiliaTheme.spaceMD,
      ),
      decoration: BoxDecoration(
        color: CertiliaTheme.surfaceColor(isDark),
        border: Border(
          bottom: BorderSide(
            color: CertiliaTheme.borderColor(isDark),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Logo
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: CertiliaTheme.primaryBlue,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Center(
                    child: Text(
                      'C',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: CertiliaTheme.spaceSM),
                Text(
                  'CERTILIA',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                    color: CertiliaTheme.textPrimaryColor(isDark),
                  ),
                ),
              ],
            ),
            // Theme and language toggles
            Row(
              children: [
                IconButton(
                  icon: Icon(
                    isDark ? Icons.light_mode : Icons.dark_mode,
                    size: 20,
                  ),
                  color: CertiliaTheme.textSecondaryColor(isDark),
                  onPressed: widget.onThemeToggle,
                  tooltip: isDark
                    ? (_isEnglish ? 'Light mode' : 'Svijetli način')
                    : (_isEnglish ? 'Dark mode' : 'Tamni način'),
                ),
                const SizedBox(width: CertiliaTheme.spaceSM),
                _buildLanguageToggle(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Build language toggle button group
  Widget _buildLanguageToggle() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: CertiliaTheme.borderColor(isDark)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          _buildLanguageButton('HR', !_isEnglish, isFirst: true),
          Container(
            width: 1,
            height: 24,
            color: CertiliaTheme.borderColor(isDark),
          ),
          _buildLanguageButton('EN', _isEnglish, isLast: true),
        ],
      ),
    );
  }

  /// Build individual language button
  Widget _buildLanguageButton(
    String label,
    bool isActive, {
    bool isFirst = false,
    bool isLast = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: () => setState(() => _isEnglish = label == 'EN'),
      borderRadius: BorderRadius.horizontal(
        left: isFirst ? const Radius.circular(5) : Radius.zero,
        right: isLast ? const Radius.circular(5) : Radius.zero,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: isActive
            ? CertiliaTheme.primaryBlue
            : Colors.transparent,
          borderRadius: BorderRadius.horizontal(
            left: isFirst ? const Radius.circular(5) : Radius.zero,
            right: isLast ? const Radius.circular(5) : Radius.zero,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isActive
              ? Colors.white
              : CertiliaTheme.textSecondaryColor(isDark),
          ),
        ),
      ),
    );
  }

  /// Build loading view
  Widget _buildLoadingView() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: SafeArea(
        child: _buildCard(
          maxWidth: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                color: CertiliaTheme.primaryBlue,
              ),
              const SizedBox(height: CertiliaTheme.spaceLG),
              Text(
                _isEnglish
                  ? 'Initializing SDK...'
                  : 'Inicijalizacija SDK-a...',
                style: CertiliaTextStyles.bodyMedium(isDark),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build unauthenticated view
  Widget _buildUnauthenticatedView() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(CertiliaTheme.spaceLG),
        child: SafeArea(
          child: _buildCard(
            maxWidth: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
              // Icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: CertiliaTheme.primaryBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(CertiliaTheme.radiusLarge),
                ),
                child: const Icon(
                  Icons.lock_outline,
                  size: 40,
                  color: CertiliaTheme.primaryBlue,
                ),
              ),
              const SizedBox(height: CertiliaTheme.spaceLG),

              // Welcome text
              Text(
                _isEnglish
                  ? 'Welcome to Certilia'
                  : 'Dobrodošli u Certilia',
                style: CertiliaTextStyles.heading(isDark),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: CertiliaTheme.spaceSM),

              Text(
                _isEnglish
                    ? 'Sign in with your Croatian eID to continue'
                    : 'Prijavite se s hrvatskom eOsobnom za nastavak',
                style: CertiliaTextStyles.bodyMedium(isDark).copyWith(
                  color: CertiliaTheme.textSecondaryColor(isDark),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: CertiliaTheme.spaceXL),

              // Sign in button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _authenticate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: CertiliaTheme.primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      vertical: CertiliaTheme.spaceMD,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(CertiliaTheme.radiusSmall),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          _isEnglish
                            ? 'Sign in with Certilia'
                            : 'Prijavite se s Certilia',
                          style: CertiliaTextStyles.button,
                        ),
                ),
              ),

                // Error message
                if (_error != null) ...[
                  const SizedBox(height: CertiliaTheme.spaceLG),
                  _buildErrorMessage(_error!),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Build authenticated view with two-column layout
  Widget _buildAuthenticatedView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(CertiliaTheme.spaceLG),
      child: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWideScreen = constraints.maxWidth > 900;

            if (isWideScreen) {
              // Two-column layout for wide screens
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildLeftColumn()),
                  const SizedBox(width: CertiliaTheme.spaceLG),
                  Expanded(child: _buildRightColumn()),
                ],
              );
            } else {
              // Single column for narrow screens
              return Column(
                children: [
                  _buildLeftColumn(),
                  const SizedBox(height: CertiliaTheme.spaceLG),
                  _buildRightColumn(),
                ],
              );
            }
          },
        ),
      ),
    );
  }

  /// Build left column content
  Widget _buildLeftColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Welcome card
        _buildWelcomeCard(),
        const SizedBox(height: CertiliaTheme.spaceMD),

        // Basic user info
        _buildBasicInfoCard(),
        const SizedBox(height: CertiliaTheme.spaceMD),

        // Token status
        _buildTokenStatusCard(),
      ],
    );
  }

  /// Build right column content
  Widget _buildRightColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Extended info or placeholder
        if (_extendedInfo != null)
          _buildExtendedInfoCard()
        else
          _buildExtendedInfoPlaceholder(),

        const SizedBox(height: CertiliaTheme.spaceMD),

        // Actions card
        _buildActionsCard(),

        // Error message
        if (_error != null) ...[
          const SizedBox(height: CertiliaTheme.spaceMD),
          _buildErrorMessage(_error!),
        ],
      ],
    );
  }

  /// Build welcome card with user greeting
  Widget _buildWelcomeCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return _buildCard(
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: CertiliaTheme.successGreen.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle,
              color: CertiliaTheme.successGreen,
              size: 28,
            ),
          ),
          const SizedBox(width: CertiliaTheme.spaceMD),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isEnglish ? 'Welcome!' : 'Dobrodošli!',
                  style: CertiliaTextStyles.label(isDark),
                ),
                const SizedBox(height: 4),
                Text(
                  _user!.fullName ?? (_isEnglish ? 'User' : 'Korisnik'),
                  style: CertiliaTextStyles.subheading(isDark),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Build basic user information card
  Widget _buildBasicInfoCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: CertiliaTheme.primaryBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.person_outline,
                  size: 20,
                  color: CertiliaTheme.primaryBlue,
                ),
              ),
              const SizedBox(width: CertiliaTheme.spaceSM),
              Text(
                _isEnglish ? 'Basic Information' : 'Osnovni podaci',
                style: CertiliaTextStyles.subheading(isDark),
              ),
            ],
          ),
          const SizedBox(height: CertiliaTheme.spaceMD),
          Divider(height: 1, color: CertiliaTheme.dividerColor(isDark)),
          const SizedBox(height: CertiliaTheme.spaceMD),

          _buildInfoRowWithIcon(
            Icons.fingerprint,
            _isEnglish ? 'User ID' : 'Korisnički ID',
            _user!.sub,
            isDark,
          ),
          _buildInfoRowWithIcon(
            Icons.badge_outlined,
            _isEnglish ? 'First Name' : 'Ime',
            _user!.firstName,
            isDark,
          ),
          _buildInfoRowWithIcon(
            Icons.badge_outlined,
            _isEnglish ? 'Last Name' : 'Prezime',
            _user!.lastName,
            isDark,
          ),
          _buildInfoRowWithIcon(
            Icons.credit_card,
            'OIB',
            _user!.oib,
            isDark,
          ),
          _buildInfoRowWithIcon(
            Icons.email_outlined,
            _isEnglish ? 'Email' : 'E-pošta',
            _user!.email,
            isDark,
          ),
          _buildInfoRowWithIcon(
            Icons.cake_outlined,
            _isEnglish ? 'Date of Birth' : 'Datum rođenja',
            _user!.dateOfBirth?.toString().split(' ')[0],
            isDark,
          ),
        ],
      ),
    );
  }

  /// Build token status card
  Widget _buildTokenStatusCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.vpn_key,
                size: 20,
                color: _isTokenExpiringSoon()
                  ? CertiliaTheme.warningOrange
                  : CertiliaTheme.successGreen,
              ),
              const SizedBox(width: CertiliaTheme.spaceSM),
              Text(
                _isEnglish ? 'Token Status' : 'Status tokena',
                style: CertiliaTextStyles.subheading(isDark),
              ),
            ],
          ),
          const SizedBox(height: CertiliaTheme.spaceMD),

          if (_tokenExpiryTime != null) ...[
            Container(
              padding: const EdgeInsets.all(CertiliaTheme.spaceSM),
              decoration: BoxDecoration(
                color: _isTokenExpiringSoon()
                    ? CertiliaTheme.warningOrange.withValues(alpha: 0.1)
                    : CertiliaTheme.successGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(CertiliaTheme.radiusSmall),
                border: Border.all(
                  color: _isTokenExpiringSoon()
                      ? CertiliaTheme.warningOrange
                      : CertiliaTheme.successGreen,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 16,
                    color: _isTokenExpiringSoon()
                        ? CertiliaTheme.warningOrange
                        : CertiliaTheme.successGreen,
                  ),
                  const SizedBox(width: CertiliaTheme.spaceSM),
                  Expanded(
                    child: Text(
                      _isEnglish
                          ? 'Expires in ${_getTimeUntilExpiry()}'
                          : 'Ističe za ${_getTimeUntilExpiry()}',
                      style: CertiliaTextStyles.bodySmall(isDark).copyWith(
                        color: _isTokenExpiringSoon()
                            ? CertiliaTheme.warningOrange
                            : CertiliaTheme.successGreen,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: CertiliaTheme.spaceSM),
            Text(
              '${_isEnglish ? 'Expires at' : 'Ističe'}: ${_formatDateTime(_tokenExpiryTime!)}',
              style: CertiliaTextStyles.bodySmall(isDark),
            ),
          ],

          const SizedBox(height: CertiliaTheme.spaceMD),

          // Access Token
          _buildTokenDisplay(
            _isEnglish ? 'Access Token' : 'Pristupni token',
            _certilia.currentAccessToken,
          ),

          const SizedBox(height: CertiliaTheme.spaceSM),

          // Refresh Token
          _buildTokenDisplay(
            _isEnglish ? 'Refresh Token' : 'Token za osvježavanje',
            _certilia.currentRefreshToken,
          ),
        ],
      ),
    );
  }

  /// Build extended information card
  Widget _buildExtendedInfoCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: CertiliaTheme.successGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.description_outlined,
                      size: 20,
                      color: CertiliaTheme.successGreen,
                    ),
                  ),
                  const SizedBox(width: CertiliaTheme.spaceSM),
                  Text(
                    _isEnglish ? 'Extended Information' : 'Prošireni podaci',
                    style: CertiliaTextStyles.subheading(isDark),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.refresh, size: 20),
                color: CertiliaTheme.primaryBlue,
                onPressed: _isLoading ? null : _getExtendedInfo,
                tooltip: _isEnglish ? 'Refresh' : 'Osvježi',
              ),
            ],
          ),
          const SizedBox(height: CertiliaTheme.spaceSM),

          Text(
            '${_extendedInfo!.availableFields.length} ${_isEnglish ? 'fields available' : 'dostupnih polja'}',
            style: CertiliaTextStyles.labelSmall(isDark).copyWith(
              color: CertiliaTheme.successGreen,
            ),
          ),

          const SizedBox(height: CertiliaTheme.spaceMD),
          Divider(height: 1, color: CertiliaTheme.dividerColor(isDark)),
          const SizedBox(height: CertiliaTheme.spaceMD),

          // Display thumbnail if available
          _buildThumbnailSection(),

          // Display formatted fields
          _buildExtendedInfoFields(),
        ],
      ),
    );
  }

  /// Build extended info placeholder
  Widget _buildExtendedInfoPlaceholder() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return _buildCard(
      child: Column(
        children: [
          Icon(
            Icons.info_outline,
            size: 48,
            color: CertiliaTheme.textTertiaryColor(isDark),
          ),
          const SizedBox(height: CertiliaTheme.spaceMD),
          Text(
            _isEnglish
              ? 'Extended information not loaded'
              : 'Prošireni podaci nisu učitani',
            style: CertiliaTextStyles.bodyMedium(isDark).copyWith(
              color: CertiliaTheme.textSecondaryColor(isDark),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: CertiliaTheme.spaceLG),
          ElevatedButton.icon(
            onPressed: _isLoading ? null : _getExtendedInfo,
            icon: const Icon(Icons.download, size: 18),
            label: Text(
              _isEnglish ? 'Load Information' : 'Učitaj podatke',
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: CertiliaTheme.primaryBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: CertiliaTheme.spaceLG,
                vertical: CertiliaTheme.spaceSM,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(CertiliaTheme.radiusSmall),
              ),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }

  /// Build actions card with buttons
  Widget _buildActionsCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: CertiliaTheme.primaryBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.settings_outlined,
                  size: 20,
                  color: CertiliaTheme.primaryBlue,
                ),
              ),
              const SizedBox(width: CertiliaTheme.spaceSM),
              Text(
                _isEnglish ? 'Actions' : 'Akcije',
                style: CertiliaTextStyles.subheading(isDark),
              ),
            ],
          ),
          const SizedBox(height: CertiliaTheme.spaceMD),

          // Refresh Token button
          ElevatedButton.icon(
            onPressed: _isLoading ? null : _refreshToken,
            icon: _isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.refresh, size: 18),
            label: Text(_isEnglish ? 'Refresh Token' : 'Osvježi token'),
            style: ElevatedButton.styleFrom(
              backgroundColor: CertiliaTheme.primaryBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                vertical: CertiliaTheme.spaceMD,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(CertiliaTheme.radiusSmall),
              ),
              elevation: 0,
            ),
          ),

          const SizedBox(height: CertiliaTheme.spaceSM),

          // Sign Out button
          OutlinedButton.icon(
            onPressed: _isLoading ? null : _logout,
            icon: const Icon(Icons.logout, size: 18),
            label: Text(_isEnglish ? 'Sign Out' : 'Odjava'),
            style: OutlinedButton.styleFrom(
              foregroundColor: CertiliaTheme.errorRed,
              side: const BorderSide(color: CertiliaTheme.errorRed),
              padding: const EdgeInsets.symmetric(
                vertical: CertiliaTheme.spaceMD,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(CertiliaTheme.radiusSmall),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build reusable card widget
  Widget _buildCard({
    required Widget child,
    double? maxWidth,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget card = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(CertiliaTheme.spaceLG),
      decoration: BoxDecoration(
        color: CertiliaTheme.surfaceColor(isDark),
        borderRadius: BorderRadius.circular(CertiliaTheme.radiusMedium),
        boxShadow: CertiliaTheme.cardShadow(isDark),
      ),
      child: child,
    );

    if (maxWidth != null) {
      return ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: card,
      );
    }

    return card;
  }


  /// Build information row with icon (label-value pair with icon)
  Widget _buildInfoRowWithIcon(
    IconData icon,
    String label,
    String? value,
    bool isDark,
  ) {
    if (value == null || value.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: CertiliaTheme.spaceMD),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: CertiliaTheme.primaryBlue.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              icon,
              size: 16,
              color: CertiliaTheme.primaryBlue,
            ),
          ),
          const SizedBox(width: CertiliaTheme.spaceSM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: CertiliaTextStyles.labelSmall(isDark),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: CertiliaTextStyles.bodyMedium(isDark),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Build token display with copy button
  Widget _buildTokenDisplay(String label, String? token) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (token == null) return const SizedBox.shrink();

    final truncatedToken = token.length > 30
        ? '${token.substring(0, 15)}...${token.substring(token.length - 15)}'
        : token;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: CertiliaTextStyles.labelSmall(isDark)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: CertiliaTheme.spaceSM,
            vertical: CertiliaTheme.spaceSM,
          ),
          decoration: BoxDecoration(
            color: CertiliaTheme.surfaceGrayColor(isDark),
            borderRadius: BorderRadius.circular(CertiliaTheme.radiusSmall),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  truncatedToken,
                  style: CertiliaTextStyles.bodySmall(isDark).copyWith(
                    fontFamily: 'monospace',
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: CertiliaTheme.spaceSM),
              InkWell(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: token));
                  _showSnackBar(
                    _isEnglish
                        ? 'Copied to clipboard'
                        : 'Kopirano u međuspremnik',
                    isSuccess: true,
                  );
                },
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.copy,
                    size: 16,
                    color: CertiliaTheme.primaryBlue,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Build error message widget
  Widget _buildErrorMessage(String message) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(CertiliaTheme.spaceMD),
      decoration: BoxDecoration(
        color: CertiliaTheme.errorRed.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(CertiliaTheme.radiusSmall),
        border: Border.all(color: CertiliaTheme.errorRed),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline,
            color: CertiliaTheme.errorRed,
            size: 20,
          ),
          const SizedBox(width: CertiliaTheme.spaceSM),
          Expanded(
            child: Text(
              message,
              style: CertiliaTextStyles.bodySmall(isDark).copyWith(
                color: CertiliaTheme.errorRed,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build thumbnail section from base64 image
  Widget _buildThumbnailSection() {
    if (_extendedInfo == null) return const SizedBox.shrink();

    final thumbnailData = _extendedInfo!.getField('thumbnail');
    if (thumbnailData == null || thumbnailData.toString().isEmpty) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    try {
      // Decode base64 image
      final bytes = base64Decode(thumbnailData.toString());

      return Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(CertiliaTheme.spaceMD),
            decoration: BoxDecoration(
              color: CertiliaTheme.surfaceGrayColor(isDark),
              borderRadius: BorderRadius.circular(CertiliaTheme.radiusMedium),
            ),
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(CertiliaTheme.radiusSmall),
                  child: Image.memory(
                    bytes,
                    width: 150,
                    height: 200,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 150,
                        height: 200,
                        decoration: BoxDecoration(
                          color: CertiliaTheme.textTertiaryColor(isDark).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(CertiliaTheme.radiusSmall),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.person_outline,
                              size: 48,
                              color: CertiliaTheme.textTertiaryColor(isDark),
                            ),
                            const SizedBox(height: CertiliaTheme.spaceSM),
                            Text(
                              _isEnglish ? 'No photo' : 'Nema fotografije',
                              style: CertiliaTextStyles.labelSmall(isDark),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: CertiliaTheme.spaceSM),
                Text(
                  _isEnglish ? 'ID Photo' : 'Fotografija s osobne',
                  style: CertiliaTextStyles.labelSmall(isDark),
                ),
              ],
            ),
          ),
          const SizedBox(height: CertiliaTheme.spaceLG),
        ],
      );
    } catch (e) {
      // If decoding fails, show placeholder
      return Container(
        margin: const EdgeInsets.only(bottom: CertiliaTheme.spaceLG),
        padding: const EdgeInsets.all(CertiliaTheme.spaceMD),
        decoration: BoxDecoration(
          color: CertiliaTheme.surfaceGrayColor(isDark),
          borderRadius: BorderRadius.circular(CertiliaTheme.radiusMedium),
        ),
        child: Column(
          children: [
            Icon(
              Icons.broken_image,
              size: 48,
              color: CertiliaTheme.textTertiaryColor(isDark),
            ),
            const SizedBox(height: CertiliaTheme.spaceSM),
            Text(
              _isEnglish ? 'Invalid image' : 'Neispravna slika',
              style: CertiliaTextStyles.labelSmall(isDark),
            ),
          ],
        ),
      );
    }
  }

  /// Build extended info fields with proper formatting
  Widget _buildExtendedInfoFields() {
    if (_extendedInfo == null) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Define field display order and labels
    final Map<String, Map<String, String>> fieldConfig = {
      'sub': {'en': 'User ID / OIB', 'hr': 'Korisnički ID / OIB', 'icon': '🆔'},
      'oib': {'en': 'OIB', 'hr': 'OIB', 'icon': '🆔', 'skip': 'true'}, // Skip as it's same as sub
      'given_name': {'en': 'First Name', 'hr': 'Ime', 'icon': '👤'},
      'first_name': {'skip': 'true'}, // Skip duplicate
      'family_name': {'en': 'Last Name', 'hr': 'Prezime', 'icon': '👤'},
      'last_name': {'skip': 'true'}, // Skip duplicate
      'full_name': {'en': 'Full Name', 'hr': 'Puno ime', 'icon': '👤'},
      'email': {'en': 'Email', 'hr': 'E-pošta', 'icon': '📧'},
      'mobile': {'en': 'Phone', 'hr': 'Telefon', 'icon': '📱', 'format': 'phone'},
      'birthdate': {'en': 'Date of Birth', 'hr': 'Datum rođenja', 'icon': '🎂', 'format': 'date'},
      'date_of_birth': {'skip': 'true'}, // Skip duplicate
      'gender': {'en': 'Gender', 'hr': 'Spol', 'icon': '⚥', 'format': 'gender'},
      'country': {'en': 'Country', 'hr': 'Država', 'icon': '🌍'},
      'formatted': {'en': 'Address', 'hr': 'Adresa', 'icon': '📍', 'format': 'address'},
      'acr': {'en': 'Auth Level', 'hr': 'Razina autentifikacije', 'icon': '🔐'},
      'amr': {'en': 'Auth Methods', 'hr': 'Metode autentifikacije', 'icon': '🔑', 'format': 'list'},
      'iss': {'en': 'Issuer', 'hr': 'Izdavatelj', 'icon': '🏛️'},
      'aud': {'en': 'Audience', 'hr': 'Publika', 'icon': '🎯'},
      'azp': {'en': 'Authorized Party', 'hr': 'Ovlaštena strana', 'icon': '✅'},
      'jti': {'en': 'Token ID', 'hr': 'ID tokena', 'icon': '🎟️'},
      'nonce': {'skip': 'true'}, // Technical field
      'at_hash': {'skip': 'true'}, // Technical field
      'c_hash': {'skip': 'true'}, // Technical field
      'thumbnail': {'skip': 'true'}, // Already displayed separately
    };

    final List<Widget> fieldWidgets = [];

    // Process fields in defined order
    for (final field in _extendedInfo!.availableFields) {
      final config = fieldConfig[field] ?? {};

      // Skip fields marked to skip or technical fields not in config
      if (config['skip'] == 'true' ||
          (config.isEmpty && !['sub', 'given_name', 'family_name', 'email', 'mobile'].contains(field))) {
        continue;
      }

      final value = _extendedInfo!.getField(field);
      if (value == null) continue;

      final label = _isEnglish ? (config['en'] ?? _formatFieldName(field)) : (config['hr'] ?? _formatFieldName(field));
      final icon = config['icon'] ?? '📄';
      final format = config['format'];

      String displayValue;

      // Format value based on type
      if (format == 'date') {
        displayValue = _formatDate(value.toString());
      } else if (format == 'phone') {
        displayValue = _formatPhoneNumber(value.toString());
      } else if (format == 'gender') {
        displayValue = _formatGender(value.toString());
      } else if (format == 'address' && value is List) {
        // Multi-line address
        fieldWidgets.add(_buildAddressField(label, icon, value, isDark));
        continue;
      } else if (format == 'list' && value is List) {
        displayValue = value.join(', ');
      } else {
        displayValue = value.toString();
      }

      fieldWidgets.add(_buildFormattedInfoRow(label, displayValue, icon, isDark));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: fieldWidgets,
    );
  }

  /// Build formatted info row with icon
  Widget _buildFormattedInfoRow(String label, String value, String icon, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: CertiliaTheme.spaceMD),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(icon, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: CertiliaTheme.spaceSM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: CertiliaTextStyles.labelSmall(isDark),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: CertiliaTextStyles.bodyMedium(isDark),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Build address field with multiple lines
  Widget _buildAddressField(String label, String icon, List<dynamic> addressLines, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: CertiliaTheme.spaceMD),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(icon, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: CertiliaTheme.spaceSM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: CertiliaTextStyles.labelSmall(isDark),
                ),
                const SizedBox(height: 4),
                ...addressLines.map((line) => Text(
                  line.toString().trim(),
                  style: CertiliaTextStyles.bodyMedium(isDark),
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Format date string to readable format
  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
    } catch (e) {
      return dateStr;
    }
  }

  /// Format phone number to readable format
  String _formatPhoneNumber(String phone) {
    if (phone.length >= 10) {
      // Format as +385 98 967 9022 for Croatian numbers
      if (phone.startsWith('385')) {
        final countryCode = phone.substring(0, 3);
        final rest = phone.substring(3);
        return '+$countryCode ${rest.substring(0, 2)} ${rest.substring(2, 5)} ${rest.substring(5)}';
      }
    }
    return phone;
  }

  /// Format gender value
  String _formatGender(String gender) {
    switch (gender.toLowerCase()) {
      case 'm':
        return _isEnglish ? 'Male' : 'Muško';
      case 'f':
        return _isEnglish ? 'Female' : 'Žensko';
      default:
        return gender;
    }
  }
}