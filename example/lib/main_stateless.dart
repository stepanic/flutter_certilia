import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_certilia/flutter_certilia.dart';

void main() {
  runApp(const MyApp());
}

/// Root app widget - manages theme state only
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isDarkMode = false;

  void _toggleTheme() {
    setState(() {
      _isDarkMode = !_isDarkMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Certilia Demo - Stateless',
      theme: CertiliaTheme.lightTheme,
      darkTheme: CertiliaTheme.darkTheme,
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      debugShowCheckedModeBanner: false,
      home: HomePage(onThemeToggle: _toggleTheme),
    );
  }
}

/// Stateless home page - no state management at all
class HomePage extends StatelessWidget {
  final VoidCallback onThemeToggle;

  const HomePage({
    super.key,
    required this.onThemeToggle,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: CertiliaTheme.backgroundColor(isDark),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(CertiliaTheme.spaceLG),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildHeader(context, isDark),
                const SizedBox(height: CertiliaTheme.spaceXL),
                _buildStatelessCard(context, isDark),
                const SizedBox(height: CertiliaTheme.spaceLG),
                _buildActionButtons(context, isDark),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Build header with logo and theme toggle
  Widget _buildHeader(BuildContext context, bool isDark) {
    return Column(
      children: [
        // Logo
        Container(
          padding: const EdgeInsets.all(CertiliaTheme.spaceLG),
          decoration: BoxDecoration(
            color: CertiliaTheme.primaryColor.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.fingerprint,
            size: 64,
            color: CertiliaTheme.primaryColor,
          ),
        ),
        const SizedBox(height: CertiliaTheme.spaceLG),

        // Title
        Text(
          'Certilia OAuth Demo',
          style: CertiliaTextStyles.headlineLarge(isDark),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: CertiliaTheme.spaceSM),

        // Subtitle
        Text(
          'Stateless Implementation',
          style: CertiliaTextStyles.bodyLarge(isDark).copyWith(
            color: CertiliaTheme.textSecondaryColor(isDark),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: CertiliaTheme.spaceLG),

        // Theme toggle
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.light_mode,
              size: 20,
              color: !isDark ? CertiliaTheme.primaryColor : CertiliaTheme.textTertiaryColor(isDark),
            ),
            const SizedBox(width: CertiliaTheme.spaceSM),
            Switch(
              value: isDark,
              onChanged: (_) => onThemeToggle(),
              activeColor: CertiliaTheme.primaryColor,
            ),
            const SizedBox(width: CertiliaTheme.spaceSM),
            Icon(
              Icons.dark_mode,
              size: 20,
              color: isDark ? CertiliaTheme.primaryColor : CertiliaTheme.textTertiaryColor(isDark),
            ),
          ],
        ),
      ],
    );
  }

  /// Build main card explaining stateless nature
  Widget _buildStatelessCard(BuildContext context, bool isDark) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 600),
      decoration: BoxDecoration(
        color: CertiliaTheme.surfaceColor(isDark),
        borderRadius: BorderRadius.circular(CertiliaTheme.radiusLarge),
        border: Border.all(
          color: CertiliaTheme.dividerColor(isDark),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(CertiliaTheme.spaceLG),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: CertiliaTheme.primaryColor,
                  size: 24,
                ),
                const SizedBox(width: CertiliaTheme.spaceMD),
                Text(
                  'Stateless Architecture',
                  style: CertiliaTextStyles.headlineSmall(isDark),
                ),
              ],
            ),
            const SizedBox(height: CertiliaTheme.spaceMD),
            Text(
              'This implementation is completely stateless:',
              style: CertiliaTextStyles.bodyMedium(isDark),
            ),
            const SizedBox(height: CertiliaTheme.spaceMD),
            _buildFeatureRow(Icons.cloud_off, 'No in-memory state storage', isDark),
            _buildFeatureRow(Icons.phone_android, 'No on-device persistence', isDark),
            _buildFeatureRow(Icons.refresh, 'No token management', isDark),
            _buildFeatureRow(Icons.person_off, 'No user data caching', isDark),
            const SizedBox(height: CertiliaTheme.spaceMD),
            Container(
              padding: const EdgeInsets.all(CertiliaTheme.spaceMD),
              decoration: BoxDecoration(
                color: CertiliaTheme.warningColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(CertiliaTheme.radiusMedium),
                border: Border.all(
                  color: CertiliaTheme.warningColor.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: CertiliaTheme.warningColor,
                    size: 20,
                  ),
                  const SizedBox(width: CertiliaTheme.spaceSM),
                  Expanded(
                    child: Text(
                      'Each action triggers a fresh OAuth flow without any state preservation.',
                      style: CertiliaTextStyles.caption(isDark).copyWith(
                        color: CertiliaTheme.warningColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: CertiliaTheme.spaceSM),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: CertiliaTheme.textSecondaryColor(isDark),
          ),
          const SizedBox(width: CertiliaTheme.spaceMD),
          Expanded(
            child: Text(
              text,
              style: CertiliaTextStyles.bodyMedium(isDark),
            ),
          ),
        ],
      ),
    );
  }

  /// Build action buttons
  Widget _buildActionButtons(BuildContext context, bool isDark) {
    return Column(
      children: [
        _buildPrimaryButton(
          context: context,
          icon: Icons.login,
          label: 'Authenticate with Certilia',
          onPressed: () => _performStatelessAuth(context),
          isDark: isDark,
        ),
        const SizedBox(height: CertiliaTheme.spaceMD),
        _buildSecondaryButton(
          context: context,
          icon: Icons.person_search,
          label: 'Fetch User Info (Stateless)',
          onPressed: () => _performStatelessUserFetch(context),
          isDark: isDark,
        ),
        const SizedBox(height: CertiliaTheme.spaceMD),
        _buildSecondaryButton(
          context: context,
          icon: Icons.info,
          label: 'About Stateless Mode',
          onPressed: () => _showAboutDialog(context),
          isDark: isDark,
        ),
      ],
    );
  }

  Widget _buildPrimaryButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required bool isDark,
  }) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 400),
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: CertiliaTheme.primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(
            horizontal: CertiliaTheme.spaceLG,
            vertical: CertiliaTheme.spaceMD,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(CertiliaTheme.radiusMedium),
          ),
        ),
      ),
    );
  }

  Widget _buildSecondaryButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required bool isDark,
  }) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 400),
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: CertiliaTheme.primaryColor,
          side: BorderSide(color: CertiliaTheme.primaryColor),
          padding: const EdgeInsets.symmetric(
            horizontal: CertiliaTheme.spaceLG,
            vertical: CertiliaTheme.spaceMD,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(CertiliaTheme.radiusMedium),
          ),
        ),
      ),
    );
  }

  /// Perform stateless authentication - no state is preserved
  Future<void> _performStatelessAuth(BuildContext context) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: CertiliaTheme.surfaceColor(isDark),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: CertiliaTheme.spaceMD),
            Text(
              'Initializing stateless OAuth flow...',
              style: CertiliaTextStyles.bodyMedium(isDark),
            ),
          ],
        ),
      ),
    );

    try {
      // Initialize SDK fresh each time (stateless)
      final certilia = await CertiliaSDKSimple.initialize(
        clientId: '991dffbb1cdd4d51423e1a5de323f13b15256c63',
        serverUrl: 'https://uniformly-credible-opossum.ngrok-free.app',
        scopes: ['openid', 'profile', 'eid', 'email', 'offline_access'],
        enableLogging: true,
      );

      if (!context.mounted) return;
      Navigator.pop(context); // Close loading dialog

      // Perform authentication (no state saved)
      final user = await certilia.authenticate(context);

      if (!context.mounted) return;

      // Show result dialog (no state preserved)
      _showResultDialog(
        context: context,
        title: 'Authentication Successful',
        content: '''
User authenticated (not stored):
• ID: ${user.sub}
• Name: ${user.fullName ?? 'N/A'}
• Email: ${user.email ?? 'N/A'}

Note: This data is NOT stored anywhere and will be lost when this dialog is closed.
        ''',
        isDark: isDark,
      );

      // Dispose SDK immediately (stateless)
      certilia.dispose();
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context); // Close loading dialog

      _showResultDialog(
        context: context,
        title: 'Authentication Failed',
        content: 'Error: $e\n\nNo state was stored.',
        isDark: isDark,
        isError: true,
      );
    }
  }

  /// Perform stateless user info fetch
  Future<void> _performStatelessUserFetch(BuildContext context) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    _showResultDialog(
      context: context,
      title: 'Stateless Operation',
      content: '''
Cannot fetch user info without authentication state.

In stateless mode:
• No tokens are stored
• No user session exists
• Each operation is independent

To get user info, you must authenticate first, but the authentication state is not preserved.
      ''',
      isDark: isDark,
      isError: false,
    );
  }

  /// Show about dialog
  void _showAboutDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: CertiliaTheme.surfaceColor(isDark),
        title: Text(
          'About Stateless Mode',
          style: CertiliaTextStyles.headlineSmall(isDark),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'This is a completely stateless implementation:',
                style: CertiliaTextStyles.bodyMedium(isDark).copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: CertiliaTheme.spaceMD),
              Text(
                '✓ No FlutterSecureStorage usage\n'
                '✓ No in-memory state variables\n'
                '✓ No token persistence\n'
                '✓ No user data caching\n'
                '✓ SDK initialized fresh for each operation\n'
                '✓ SDK disposed immediately after use',
                style: CertiliaTextStyles.bodyMedium(isDark),
              ),
              const SizedBox(height: CertiliaTheme.spaceMD),
              Text(
                'Benefits:',
                style: CertiliaTextStyles.bodyMedium(isDark).copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: CertiliaTheme.spaceSM),
              Text(
                '• Maximum security (no data retention)\n'
                '• No state synchronization issues\n'
                '• Predictable behavior\n'
                '• Easy to test',
                style: CertiliaTextStyles.bodyMedium(isDark),
              ),
              const SizedBox(height: CertiliaTheme.spaceMD),
              Text(
                'Limitations:',
                style: CertiliaTextStyles.bodyMedium(isDark).copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: CertiliaTheme.spaceSM),
              Text(
                '• User must authenticate for every operation\n'
                '• No session persistence\n'
                '• No token refresh capability\n'
                '• Not suitable for production use',
                style: CertiliaTextStyles.bodyMedium(isDark),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Close',
              style: TextStyle(color: CertiliaTheme.primaryColor),
            ),
          ),
        ],
      ),
    );
  }

  /// Show result dialog
  void _showResultDialog({
    required BuildContext context,
    required String title,
    required String content,
    required bool isDark,
    bool isError = false,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: CertiliaTheme.surfaceColor(isDark),
        title: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: isError ? CertiliaTheme.errorColor : CertiliaTheme.successColor,
            ),
            const SizedBox(width: CertiliaTheme.spaceMD),
            Text(
              title,
              style: CertiliaTextStyles.headlineSmall(isDark),
            ),
          ],
        ),
        content: Text(
          content,
          style: CertiliaTextStyles.bodyMedium(isDark),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'OK',
              style: TextStyle(color: CertiliaTheme.primaryColor),
            ),
          ),
        ],
      ),
    );
  }
}

/// Theme configuration
class CertiliaTheme {
  // Colors
  static const Color primaryColor = Color(0xFF1976D2);
  static const Color secondaryColor = Color(0xFF424242);
  static const Color errorColor = Color(0xFFD32F2F);
  static const Color warningColor = Color(0xFFF57C00);
  static const Color successColor = Color(0xFF388E3C);

  // Spacing
  static const double spaceSM = 8.0;
  static const double spaceMD = 16.0;
  static const double spaceLG = 24.0;
  static const double spaceXL = 32.0;

  // Border radius
  static const double radiusSmall = 4.0;
  static const double radiusMedium = 8.0;
  static const double radiusLarge = 12.0;

  // Dynamic colors based on theme
  static Color backgroundColor(bool isDark) =>
      isDark ? const Color(0xFF121212) : const Color(0xFFF5F5F5);

  static Color surfaceColor(bool isDark) =>
      isDark ? const Color(0xFF1E1E1E) : Colors.white;

  static Color surfaceGrayColor(bool isDark) =>
      isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF5F5F5);

  static Color textPrimaryColor(bool isDark) =>
      isDark ? Colors.white : const Color(0xFF212121);

  static Color textSecondaryColor(bool isDark) =>
      isDark ? Colors.white70 : const Color(0xFF757575);

  static Color textTertiaryColor(bool isDark) =>
      isDark ? Colors.white54 : const Color(0xFF9E9E9E);

  static Color dividerColor(bool isDark) =>
      isDark ? Colors.white12 : const Color(0xFFE0E0E0);

  // Themes
  static ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    primarySwatch: Colors.blue,
    scaffoldBackgroundColor: backgroundColor(false),
  );

  static ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    primarySwatch: Colors.blue,
    scaffoldBackgroundColor: backgroundColor(true),
  );
}

/// Text styles
class CertiliaTextStyles {
  static TextStyle headlineLarge(bool isDark) => TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    color: CertiliaTheme.textPrimaryColor(isDark),
  );

  static TextStyle headlineSmall(bool isDark) => TextStyle(
    fontSize: 20,
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

  static TextStyle caption(bool isDark) => TextStyle(
    fontSize: 12,
    color: CertiliaTheme.textSecondaryColor(isDark),
  );
}