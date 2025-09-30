import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_certilia/flutter_certilia.dart';

void main() {
  runApp(const MyApp());
}

// Theme colors from SMPLTSK
class CertiliaTheme {
  static const Color primaryBlue = Color(0xFF1E40AF);
  static const Color primaryDarkBlue = Color(0xFF1E3A8A);
  static const Color darkBackground = Color(0xFF0F172A);
  static const Color secondaryGreen = Color(0xFF10B981);
  static const Color accentPurple = Color(0xFF7C3AED);
  static const Color warningOrange = Color(0xFFF59E0B);
  static const Color errorRed = Color(0xFFEF4444);
  static const Color textLight = Color(0xFFCBD5E1);
  static const Color surfaceDark = Color(0xFF1E293B);
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Certilia SDK Example',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        primaryColor: CertiliaTheme.primaryBlue,
        scaffoldBackgroundColor: CertiliaTheme.darkBackground,
        colorScheme: const ColorScheme.dark(
          primary: CertiliaTheme.primaryBlue,
          secondary: CertiliaTheme.secondaryGreen,
          tertiary: CertiliaTheme.accentPurple,
          error: CertiliaTheme.errorRed,
          surface: CertiliaTheme.surfaceDark,
        ),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  dynamic _certilia;
  CertiliaUser? _user;
  CertiliaExtendedInfo? _extendedInfo;
  bool _isLoading = false;
  bool _isInitialized = false;
  String? _error;
  DateTime? _tokenExpiryTime;
  bool _isEnglish = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
    _initializeSDK();
  }

  @override
  void dispose() {
    _animationController.dispose();
    if (_isInitialized) {
      _certilia.dispose();
    }
    super.dispose();
  }

  Future<void> _initializeSDK() async {
    setState(() {
      _isLoading = true;
    });

    try {
      _certilia = await CertiliaSDKSimple.initialize(
        clientId: '991dffbb1cdd4d51423e1a5de323f13b15256c63',
        serverUrl: 'https://uniformly-credible-opossum.ngrok-free.app',
        scopes: ['openid', 'profile', 'eid', 'email', 'offline_access'],
        enableLogging: true,
        sessionTimeout: 3600000,
      );

      setState(() {
        _isInitialized = true;
        _isLoading = false;
      });

      Future.delayed(const Duration(milliseconds: 100), () {
        _checkAuthStatus();
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Failed to initialize SDK: $e';
      });
    }
  }

  Future<void> _checkAuthStatus() async {
    if (!_isInitialized) return;

    final isAuth = await _certilia.checkAuthenticationStatus();

    if (isAuth) {
      try {
        final user = await _certilia.getCurrentUser();
        if (!mounted) return;

        setState(() {
          _user = user;
        });
        if (user != null) {
          await _getExtendedInfo();
        }
      } catch (e) {
        debugPrint('Failed to get current user: $e');
        if (!_certilia.isAuthenticated && mounted) {
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
    }
  }

  Future<void> _authenticate() async {
    if (!_isInitialized) {
      _showSnackBar(_isEnglish ? 'Please wait for SDK initialization' : 'Molimo pričekajte inicijalizaciju SDK-a');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final user = await _certilia.authenticate(context);
      if (!mounted) return;

      setState(() {
        _user = user;
        _isLoading = false;
      });

      await _getExtendedInfo();
    } on CertiliaAuthenticationException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Authentication failed: ${e.message}';
        _isLoading = false;
      });
    } on CertiliaNetworkException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Network error: ${e.message}';
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Unexpected error: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _getExtendedInfo() async {
    if (!mounted || !_isInitialized) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final extendedInfo = await _certilia.getExtendedUserInfo();
      if (!mounted) return;

      if (extendedInfo == null && !_certilia.isAuthenticated) {
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

      setState(() {
        _extendedInfo = extendedInfo;
        _tokenExpiryTime = extendedInfo?.tokenExpiry;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to get extended info: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshToken() async {
    if (!_isInitialized) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await _certilia.refreshToken();
      setState(() {
        _isLoading = false;
      });

      _showSnackBar(
        _isEnglish ? 'Token refreshed successfully' : 'Token uspješno osvježen',
        isSuccess: true,
      );

      await _checkAuthStatus();
      await _getExtendedInfo();
    } catch (e) {
      setState(() {
        _error = 'Token refresh failed: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _logout() async {
    if (!_isInitialized) return;

    setState(() {
      _isLoading = true;
    });

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
        _error = 'Logout failed: $e';
        _isLoading = false;
      });
    }
  }

  void _showSnackBar(String message, {bool isSuccess = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isSuccess ? CertiliaTheme.secondaryGreen : null,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  bool _isTokenExpiringSoon() {
    if (_tokenExpiryTime == null) return false;
    final timeUntilExpiry = _tokenExpiryTime!.difference(DateTime.now());
    return timeUntilExpiry.inMinutes < 5;
  }

  String _getTimeUntilExpiry() {
    if (_tokenExpiryTime == null) return _isEnglish ? 'Unknown' : 'Nepoznato';

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

  String _formatFieldName(String fieldName) {
    return fieldName
        .split('_')
        .map((word) => word.isNotEmpty
            ? '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}'
            : '')
        .join(' ');
  }

  String _formatDateTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    return '${local.day}.${local.month}.${local.year} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              CertiliaTheme.primaryBlue,
              CertiliaTheme.primaryDarkBlue,
              CertiliaTheme.darkBackground,
            ],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              children: [
                // Header with language toggle
                _buildHeader(),

                // Main content
                Expanded(
                  child: _isInitialized
                      ? (_user != null ? _buildAuthenticatedView() : _buildUnauthenticatedView())
                      : _buildLoadingView(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Certilia SDK',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          Row(
            children: [
              _buildLanguageButton('HR', !_isEnglish),
              const SizedBox(width: 8),
              _buildLanguageButton('EN', _isEnglish),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageButton(String label, bool isActive) {
    return GestureDetector(
      onTap: () => setState(() => _isEnglish = label == 'EN'),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? CertiliaTheme.secondaryGreen
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive
                ? CertiliaTheme.secondaryGreen
                : Colors.white.withValues(alpha: 0.3),
            width: 2,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.7),
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  CertiliaTheme.primaryBlue.withValues(alpha: 0.3),
                  CertiliaTheme.secondaryGreen.withValues(alpha: 0.3),
                ],
              ),
            ),
            child: const Center(
              child: CircularProgressIndicator(
                color: CertiliaTheme.secondaryGreen,
                strokeWidth: 3,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            _isEnglish ? 'Initializing SDK...' : 'Inicijalizacija SDK-a...',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnauthenticatedView() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    CertiliaTheme.primaryBlue.withValues(alpha: 0.3),
                    CertiliaTheme.secondaryGreen.withValues(alpha: 0.3),
                  ],
                ),
              ),
              child: const Icon(
                Icons.lock_outline,
                size: 60,
                color: CertiliaTheme.secondaryGreen,
              ),
            ),
            const SizedBox(height: 48),
            Text(
              _isEnglish ? 'Welcome to Certilia' : 'Dobrodošli u Certilia',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              _isEnglish
                  ? 'Sign in with your Croatian eID'
                  : 'Prijavite se s hrvatskom osobnom iskaznicom',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 18,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _authenticate,
              style: ElevatedButton.styleFrom(
                backgroundColor: CertiliaTheme.secondaryGreen,
                padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.login, color: Colors.white),
              label: Text(
                _isLoading
                    ? (_isEnglish ? 'Signing in...' : 'Prijava...')
                    : (_isEnglish ? 'Sign in with Certilia' : 'Prijavite se s Certilia'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: CertiliaTheme.errorRed.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: CertiliaTheme.errorRed,
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: CertiliaTheme.errorRed),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(
                          color: CertiliaTheme.errorRed,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAuthenticatedView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Welcome section
          Container(
            width: 100,
            height: 100,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  CertiliaTheme.primaryBlue,
                  CertiliaTheme.secondaryGreen,
                ],
              ),
            ),
            child: const Icon(
              Icons.check_circle,
              size: 50,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            _isEnglish
                ? 'Welcome, ${_user!.fullName ?? 'User'}!'
                : 'Dobrodošli, ${_user!.fullName ?? 'Korisnik'}!',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          // Basic user info card
          _buildInfoCard(
            title: _isEnglish ? 'Basic User Info' : 'Osnovni podaci',
            icon: Icons.person,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow('ID', _user!.sub),
                _buildInfoRow(_isEnglish ? 'First Name' : 'Ime', _user!.firstName),
                _buildInfoRow(_isEnglish ? 'Last Name' : 'Prezime', _user!.lastName),
                _buildInfoRow('OIB', _user!.oib),
                _buildInfoRow(_isEnglish ? 'Email' : 'E-pošta', _user!.email),
                _buildInfoRow(
                  _isEnglish ? 'Date of Birth' : 'Datum rođenja',
                  _user!.dateOfBirth?.toString().split(' ')[0],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Extended info card
          if (_extendedInfo != null) ...[
            _buildInfoCard(
              title: _isEnglish ? 'Extended User Info' : 'Prošireni podaci',
              icon: Icons.info_outline,
              trailing: IconButton(
                icon: const Icon(Icons.refresh, color: CertiliaTheme.secondaryGreen),
                onPressed: _isLoading ? null : _getExtendedInfo,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isEnglish
                        ? 'Total fields: ${_extendedInfo!.availableFields.length}'
                        : 'Ukupno polja: ${_extendedInfo!.availableFields.length}',
                    style: TextStyle(
                      color: CertiliaTheme.secondaryGreen,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ..._extendedInfo!.availableFields.map((field) {
                    final value = _extendedInfo!.getField(field)?.toString();
                    if (value == null || value.isEmpty) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 2,
                            child: Text(
                              _formatFieldName(field),
                              style: const TextStyle(
                                color: CertiliaTheme.textLight,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 3,
                            child: Text(
                              value,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  if (_extendedInfo!.tokenExpiry != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: CertiliaTheme.primaryBlue.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.access_time,
                            size: 16,
                            color: CertiliaTheme.secondaryGreen,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _isEnglish
                                  ? 'Token expires: ${_formatDateTime(_extendedInfo!.tokenExpiry!)}'
                                  : 'Token ističe: ${_formatDateTime(_extendedInfo!.tokenExpiry!)}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: CertiliaTheme.textLight,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ] else if (!_isLoading) ...[
            ElevatedButton.icon(
              onPressed: _getExtendedInfo,
              style: ElevatedButton.styleFrom(
                backgroundColor: CertiliaTheme.accentPurple,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.info_outline, color: Colors.white),
              label: Text(
                _isEnglish ? 'Get Extended Info' : 'Dohvati proširene podatke',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Token info card
          _buildInfoCard(
            title: _isEnglish ? 'Authentication Tokens' : 'Autentifikacijski tokeni',
            icon: Icons.key,
            child: Column(
              children: [
                _buildTokenRow(
                  'Access Token',
                  _certilia.currentAccessToken,
                  Icons.vpn_key,
                ),
                const SizedBox(height: 12),
                _buildTokenRow(
                  'Refresh Token',
                  _certilia.currentRefreshToken,
                  Icons.refresh,
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Token expiry warning
          if (_tokenExpiryTime != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _isTokenExpiringSoon()
                    ? CertiliaTheme.warningOrange.withValues(alpha: 0.2)
                    : CertiliaTheme.secondaryGreen.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _isTokenExpiringSoon()
                      ? CertiliaTheme.warningOrange
                      : CertiliaTheme.secondaryGreen,
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.access_time,
                    color: _isTokenExpiringSoon()
                        ? CertiliaTheme.warningOrange
                        : CertiliaTheme.secondaryGreen,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _isEnglish
                          ? 'Token expires in: ${_getTimeUntilExpiry()}'
                          : 'Token ističe za: ${_getTimeUntilExpiry()}',
                      style: TextStyle(
                        color: _isTokenExpiringSoon()
                            ? CertiliaTheme.warningOrange
                            : CertiliaTheme.secondaryGreen,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Action buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _refreshToken,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: CertiliaTheme.primaryBlue,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.refresh, color: Colors.white, size: 20),
                  label: Text(
                    _isEnglish ? 'Refresh' : 'Osvježi',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _logout,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: CertiliaTheme.errorRed,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.logout, color: Colors.white, size: 20),
                  label: Text(
                    _isEnglish ? 'Logout' : 'Odjava',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),

          if (_isLoading) ...[
            const SizedBox(height: 24),
            const CircularProgressIndicator(
              color: CertiliaTheme.secondaryGreen,
            ),
          ],

          if (_error != null) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: CertiliaTheme.errorRed.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: CertiliaTheme.errorRed,
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: CertiliaTheme.errorRed),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _error!,
                      style: const TextStyle(color: CertiliaTheme.errorRed),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required IconData icon,
    required Widget child,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: CertiliaTheme.surfaceDark.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: CertiliaTheme.secondaryGreen, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                color: CertiliaTheme.textLight,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTokenRow(String label, String? token, IconData icon) {
    if (token == null) return const SizedBox.shrink();

    final truncatedToken = token.length > 50
        ? '${token.substring(0, 20)}...${token.substring(token.length - 20)}'
        : token;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CertiliaTheme.darkBackground.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: CertiliaTheme.secondaryGreen),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: CertiliaTheme.textLight,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.copy, size: 16),
                color: CertiliaTheme.secondaryGreen,
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: token));
                  _showSnackBar(
                    _isEnglish
                        ? '$label copied to clipboard'
                        : '$label kopiran u međuspremnik',
                    isSuccess: true,
                  );
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SelectableText(
            truncatedToken,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}