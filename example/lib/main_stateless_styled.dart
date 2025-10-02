import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_certilia/flutter_certilia.dart';
import 'package:flutter_certilia/src/certilia_stateful_wrapper.dart';
import 'package:flutter_certilia/src/certilia_webview_client.dart';
import 'package:flutter_certilia/src/models/certilia_config.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.light;

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
      title: 'Certilia SDK Demo',
      theme: CertiliaTheme.lightTheme,
      darkTheme: CertiliaTheme.darkTheme,
      themeMode: _themeMode,
      home: HomePage(onThemeToggle: _toggleTheme),
      debugShowCheckedModeBanner: false,
    );
  }
}

/// Stateless home page with stateful-like UI
class HomePage extends StatelessWidget {
  final VoidCallback onThemeToggle;

  const HomePage({
    super.key,
    required this.onThemeToggle,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _loadUserState(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingScaffold(context);
        }

        final hasToken = snapshot.data?['hasToken'] ?? false;
        final user = snapshot.data?['user'] as CertiliaUser?;

        return _StatelessAuthView(
          onThemeToggle: onThemeToggle,
          hasStoredToken: hasToken,
          storedUser: user,
        );
      },
    );
  }

  Future<Map<String, dynamic>> _loadUserState() async {
    final hasToken = await CertiliaStatefulWrapper.hasValidStoredToken();
    final user = hasToken ? await CertiliaStatefulWrapper.getStoredUser() : null;
    return {
      'hasToken': hasToken,
      'user': user,
    };
  }

  Widget _buildLoadingScaffold(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: CertiliaTheme.backgroundColor(isDark),
      body: Center(
        child: CircularProgressIndicator(
          color: CertiliaTheme.primaryBlue,
        ),
      ),
    );
  }
}

/// Main stateless auth view
class _StatelessAuthView extends StatelessWidget {
  final VoidCallback onThemeToggle;
  final bool hasStoredToken;
  final CertiliaUser? storedUser;

  const _StatelessAuthView({
    required this.onThemeToggle,
    required this.hasStoredToken,
    this.storedUser,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEnglish = Localizations.localeOf(context).languageCode != 'hr';

    return Scaffold(
      backgroundColor: CertiliaTheme.backgroundColor(isDark),
      body: Column(
        children: [
          _buildHeader(context, isDark, isEnglish),
          Expanded(
            child: hasStoredToken && storedUser != null
                ? _buildAuthenticatedView(context, storedUser!, isDark, isEnglish)
                : _buildUnauthenticatedView(context, isDark, isEnglish),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark, bool isEnglish) {
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
            // Theme toggle
            IconButton(
              icon: Icon(
                isDark ? Icons.light_mode : Icons.dark_mode,
                size: 20,
              ),
              color: CertiliaTheme.textSecondaryColor(isDark),
              onPressed: onThemeToggle,
              tooltip: isDark
                ? (isEnglish ? 'Light mode' : 'Svijetli način')
                : (isEnglish ? 'Dark mode' : 'Tamni način'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnauthenticatedView(BuildContext context, bool isDark, bool isEnglish) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(CertiliaTheme.spaceLG),
        child: SafeArea(
          child: _buildCard(
            isDark: isDark,
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
                  isEnglish
                    ? 'Welcome to Certilia'
                    : 'Dobrodošli u Certilia',
                  style: CertiliaTextStyles.heading(isDark),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: CertiliaTheme.spaceSM),

                Text(
                  isEnglish
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
                    onPressed: () => _authenticate(context),
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
                    child: Text(
                      isEnglish
                        ? 'Sign in with Certilia'
                        : 'Prijavite se s Certilia',
                      style: CertiliaTextStyles.button,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAuthenticatedView(BuildContext context, CertiliaUser user, bool isDark, bool isEnglish) {
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
                  Expanded(child: _buildLeftColumn(context, user, isDark, isEnglish)),
                  const SizedBox(width: CertiliaTheme.spaceLG),
                  Expanded(child: _buildRightColumn(context, isDark, isEnglish)),
                ],
              );
            } else {
              // Single column for narrow screens
              return Column(
                children: [
                  _buildLeftColumn(context, user, isDark, isEnglish),
                  const SizedBox(height: CertiliaTheme.spaceLG),
                  _buildRightColumn(context, isDark, isEnglish),
                ],
              );
            }
          },
        ),
      ),
    );
  }

  Widget _buildLeftColumn(BuildContext context, CertiliaUser user, bool isDark, bool isEnglish) {
    return Column(
      children: [
        _buildUserCard(context, user, isDark, isEnglish),
        const SizedBox(height: CertiliaTheme.spaceLG),
        _buildExtendedInfoCard(context, isDark, isEnglish),
      ],
    );
  }

  Widget _buildRightColumn(BuildContext context, bool isDark, bool isEnglish) {
    return Column(
      children: [
        _buildActionsCard(context, isDark, isEnglish),
        const SizedBox(height: CertiliaTheme.spaceLG),
        _buildTokenCard(context, isDark, isEnglish),
      ],
    );
  }

  Widget _buildUserCard(BuildContext context, CertiliaUser user, bool isDark, bool isEnglish) {
    return _buildCard(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      CertiliaTheme.primaryBlue,
                      CertiliaTheme.primaryBlue.withValues(alpha: 0.7),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    user.firstName?.substring(0, 1).toUpperCase() ?? 'U',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: CertiliaTheme.spaceMD),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.fullName ?? 'User',
                      style: CertiliaTextStyles.heading(isDark),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user.email ?? 'No email',
                      style: CertiliaTextStyles.bodySmall(isDark).copyWith(
                        color: CertiliaTheme.textSecondaryColor(isDark),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: CertiliaTheme.spaceLG),
          Divider(height: 1, color: CertiliaTheme.dividerColor(isDark)),
          const SizedBox(height: CertiliaTheme.spaceLG),

          _buildInfoRow(
            Icons.fingerprint,
            isEnglish ? 'User ID' : 'Korisnički ID',
            user.sub,
            isDark,
          ),
          if (user.oib != null)
            _buildInfoRow(
              Icons.badge,
              'OIB',
              user.oib!,
              isDark,
            ),
          if (user.dateOfBirth != null)
            _buildInfoRow(
              Icons.cake,
              isEnglish ? 'Date of Birth' : 'Datum rođenja',
              '${user.dateOfBirth!.day}.${user.dateOfBirth!.month}.${user.dateOfBirth!.year}',
              isDark,
            ),
        ],
      ),
    );
  }

  Widget _buildExtendedInfoCard(BuildContext context, bool isDark, bool isEnglish) {
    return _buildCard(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isEnglish ? 'Extended Information' : 'Proširene informacije',
                style: CertiliaTextStyles.subheading(isDark),
              ),
              TextButton(
                onPressed: () => _fetchExtendedInfo(context),
                child: Text(
                  isEnglish ? 'Fetch' : 'Dohvati',
                  style: TextStyle(color: CertiliaTheme.primaryBlue),
                ),
              ),
            ],
          ),
          const SizedBox(height: CertiliaTheme.spaceMD),
          Text(
            isEnglish
              ? 'Click "Fetch" to load extended user information using the stored token.'
              : 'Kliknite "Dohvati" za učitavanje proširenih korisničkih informacija pomoću spremljenog tokena.',
            style: CertiliaTextStyles.bodySmall(isDark).copyWith(
              color: CertiliaTheme.textSecondaryColor(isDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionsCard(BuildContext context, bool isDark, bool isEnglish) {
    return _buildCard(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isEnglish ? 'Actions' : 'Akcije',
            style: CertiliaTextStyles.subheading(isDark),
          ),
          const SizedBox(height: CertiliaTheme.spaceLG),

          // Refresh Token Button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _refreshToken(context),
              icon: const Icon(Icons.refresh, size: 18),
              label: Text(
                isEnglish ? 'Refresh Token' : 'Osvježi token',
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: CertiliaTheme.primaryBlue,
                side: BorderSide(color: CertiliaTheme.primaryBlue),
                padding: const EdgeInsets.symmetric(
                  vertical: CertiliaTheme.spaceMD,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(CertiliaTheme.radiusSmall),
                ),
              ),
            ),
          ),
          const SizedBox(height: CertiliaTheme.spaceMD),

          // Logout Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _logout(context),
              icon: const Icon(Icons.logout, size: 18),
              label: Text(
                isEnglish ? 'Sign Out' : 'Odjavi se',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: CertiliaTheme.errorRed,
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
          ),
        ],
      ),
    );
  }

  Widget _buildTokenCard(BuildContext context, bool isDark, bool isEnglish) {
    return _buildCard(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isEnglish ? 'Token Status' : 'Status tokena',
            style: CertiliaTextStyles.subheading(isDark),
          ),
          const SizedBox(height: CertiliaTheme.spaceLG),

          Container(
            padding: const EdgeInsets.all(CertiliaTheme.spaceMD),
            decoration: BoxDecoration(
              color: CertiliaTheme.successGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(CertiliaTheme.radiusSmall),
              border: Border.all(
                color: CertiliaTheme.successGreen.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle,
                  color: CertiliaTheme.successGreen,
                  size: 20,
                ),
                const SizedBox(width: CertiliaTheme.spaceSM),
                Expanded(
                  child: Text(
                    isEnglish ? 'Valid token stored' : 'Valjan token spremljen',
                    style: CertiliaTextStyles.bodySmall(isDark).copyWith(
                      color: CertiliaTheme.successGreen,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: CertiliaTheme.spaceMD),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: CertiliaTheme.textSecondaryColor(isDark),
          ),
          const SizedBox(width: CertiliaTheme.spaceMD),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: CertiliaTextStyles.labelSmall(isDark),
                ),
                const SizedBox(height: 2),
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

  Widget _buildCard({
    required Widget child,
    required bool isDark,
    double? maxWidth,
  }) {
    Widget card = Container(
      decoration: BoxDecoration(
        color: CertiliaTheme.surfaceColor(isDark),
        borderRadius: BorderRadius.circular(CertiliaTheme.radiusLarge),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.2)
                : Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(CertiliaTheme.spaceLG),
      child: child,
    );

    if (maxWidth != null) {
      card = Container(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: card,
      );
    }

    return card;
  }

  // Action methods
  Future<void> _authenticate(BuildContext context) async {
    _showLoadingDialog(context, 'Authenticating...');

    try {
      final certilia = await CertiliaSDKSimple.initialize(
        clientId: '991dffbb1cdd4d51423e1a5de323f13b15256c63',
        serverUrl: 'https://uniformly-credible-opossum.ngrok-free.app',
        scopes: ['openid', 'profile', 'eid', 'email', 'offline_access'],
        enableLogging: true,
      );

      if (!context.mounted) return;
      Navigator.pop(context); // Close loading

      final user = await certilia.authenticate(context);

      if (!context.mounted) return;

      // Refresh the page to show authenticated state
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => HomePage(onThemeToggle: onThemeToggle),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context);
      _showErrorDialog(context, 'Authentication failed: $e');
    }
  }

  Future<void> _fetchExtendedInfo(BuildContext context) async {
    _showLoadingDialog(context, 'Fetching extended info...');

    try {
      final token = await CertiliaStatefulWrapper.getStoredAccessToken();
      if (token == null) throw Exception('No valid token');

      final client = CertiliaWebViewClient(
        config: CertiliaConfig(
          clientId: '991dffbb1cdd4d51423e1a5de323f13b15256c63',
          redirectUrl: 'https://uniformly-credible-opossum.ngrok-free.app/api/auth/callback',
          scopes: ['openid', 'profile', 'eid', 'email', 'offline_access'],
          baseUrl: 'https://idp.certilia.com',
          authorizationEndpoint: 'https://idp.certilia.com/oauth2/authorize',
          tokenEndpoint: 'https://idp.certilia.com/oauth2/token',
          userInfoEndpoint: 'https://idp.certilia.com/oauth2/userinfo',
        ),
        serverUrl: 'https://uniformly-credible-opossum.ngrok-free.app',
      );

      final extendedInfo = await client.getExtendedUserInfo(token);
      client.dispose();

      if (!context.mounted) return;
      Navigator.pop(context);

      final fields = extendedInfo?.availableFields.join(', ') ?? 'None';
      _showInfoDialog(context, 'Extended Info', 'Available fields:\n$fields');
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context);
      _showErrorDialog(context, 'Failed to fetch: $e');
    }
  }

  Future<void> _refreshToken(BuildContext context) async {
    _showLoadingDialog(context, 'Refreshing token...');

    try {
      final accessToken = await CertiliaStatefulWrapper.getStoredAccessToken();
      final refreshToken = await CertiliaStatefulWrapper.getStoredRefreshToken();

      if (accessToken == null || refreshToken == null) {
        throw Exception('No tokens available');
      }

      final client = CertiliaWebViewClient(
        config: CertiliaConfig(
          clientId: '991dffbb1cdd4d51423e1a5de323f13b15256c63',
          redirectUrl: 'https://uniformly-credible-opossum.ngrok-free.app/api/auth/callback',
          scopes: ['openid', 'profile', 'eid', 'email', 'offline_access'],
          baseUrl: 'https://idp.certilia.com',
          authorizationEndpoint: 'https://idp.certilia.com/oauth2/authorize',
          tokenEndpoint: 'https://idp.certilia.com/oauth2/token',
          userInfoEndpoint: 'https://idp.certilia.com/oauth2/userinfo',
          enableLogging: true,
        ),
        serverUrl: 'https://uniformly-credible-opossum.ngrok-free.app',
      );

      await client.refreshToken(
        accessToken: accessToken,
        refreshToken: refreshToken,
      );

      client.dispose();

      if (!context.mounted) return;
      Navigator.pop(context);
      _showSuccessDialog(context, 'Token refreshed successfully');
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context);
      _showErrorDialog(context, 'Refresh failed: $e');
    }
  }

  Future<void> _logout(BuildContext context) async {
    await CertiliaStatefulWrapper.clearStoredData();

    if (!context.mounted) return;

    // Refresh the page to show unauthenticated state
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => HomePage(onThemeToggle: onThemeToggle),
      ),
    );
  }

  void _showLoadingDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 20),
            Text(message),
          ],
        ),
      ),
    );
  }

  void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showInfoDialog(BuildContext context, String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: CertiliaTheme.successGreen),
            SizedBox(width: 8),
            Text('Success'),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

// Include all CertiliaTheme and CertiliaTextStyles from main_stateful_backup.dart
class CertiliaTheme {
  // Colors
  static const Color primaryBlue = Color(0xFF2196F3);
  static const Color successGreen = Color(0xFF4CAF50);
  static const Color errorRed = Color(0xFFF44336);
  static const Color warningOrange = Color(0xFFFF9800);

  // Spacing
  static const double spaceSM = 8.0;
  static const double spaceMD = 16.0;
  static const double spaceLG = 24.0;
  static const double spaceXL = 32.0;

  // Border radius
  static const double radiusSmall = 8.0;
  static const double radiusMedium = 12.0;
  static const double radiusLarge = 16.0;

  // Dynamic colors based on theme
  static Color backgroundColor(bool isDark) =>
      isDark ? const Color(0xFF121212) : const Color(0xFFF5F5F5);

  static Color surfaceColor(bool isDark) =>
      isDark ? const Color(0xFF1E1E1E) : Colors.white;

  static Color surfaceGrayColor(bool isDark) =>
      isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF8F8F8);

  static Color borderColor(bool isDark) =>
      isDark ? const Color(0xFF2C2C2C) : const Color(0xFFE0E0E0);

  static Color dividerColor(bool isDark) =>
      isDark ? const Color(0xFF2C2C2C) : const Color(0xFFE0E0E0);

  static Color textPrimaryColor(bool isDark) =>
      isDark ? Colors.white : const Color(0xFF1A1A1A);

  static Color textSecondaryColor(bool isDark) =>
      isDark ? Colors.white70 : const Color(0xFF757575);

  static Color textTertiaryColor(bool isDark) =>
      isDark ? Colors.white54 : const Color(0xFF9E9E9E);

  // Themes
  static final ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    primaryColor: primaryBlue,
    scaffoldBackgroundColor: backgroundColor(false),
    colorScheme: const ColorScheme.light(primary: primaryBlue),
  );

  static final ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    primaryColor: primaryBlue,
    scaffoldBackgroundColor: backgroundColor(true),
    colorScheme: const ColorScheme.dark(primary: primaryBlue),
  );
}

class CertiliaTextStyles {
  static TextStyle heading(bool isDark) => TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: CertiliaTheme.textPrimaryColor(isDark),
  );

  static TextStyle subheading(bool isDark) => TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: CertiliaTheme.textPrimaryColor(isDark),
  );

  static TextStyle bodyLarge(bool isDark) => TextStyle(
    fontSize: 16,
    color: CertiliaTheme.textPrimaryColor(isDark),
  );

  static TextStyle bodyMedium(bool isDark) => TextStyle(
    fontSize: 14,
    color: CertiliaTheme.textPrimaryColor(isDark),
  );

  static TextStyle bodySmall(bool isDark) => TextStyle(
    fontSize: 12,
    color: CertiliaTheme.textPrimaryColor(isDark),
  );

  static TextStyle labelSmall(bool isDark) => TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: CertiliaTheme.textSecondaryColor(isDark),
    letterSpacing: 0.5,
  );

  static const TextStyle button = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
  );
}