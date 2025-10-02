import 'package:flutter/material.dart';
import '../theme/certilia_theme.dart';

/// Login view widget for unauthenticated users
class LoginView extends StatelessWidget {
  final bool isDark;
  final bool isEnglish;
  final String? errorMessage;
  final VoidCallback onAuthenticate;
  final VoidCallback onToggleLanguage;
  final VoidCallback? onThemeToggle;

  const LoginView({
    super.key,
    required this.isDark,
    required this.isEnglish,
    this.errorMessage,
    required this.onAuthenticate,
    required this.onToggleLanguage,
    this.onThemeToggle,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(CertiliaTheme.spaceLG),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildHeader(),
              const SizedBox(height: CertiliaTheme.spaceXL * 2),
              _buildLoginCard(context),
              const SizedBox(height: CertiliaTheme.spaceLG),
              _buildControlButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        // Certilia Logo/Icon
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: CertiliaTheme.primaryBlue,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: CertiliaTheme.primaryBlue.withValues(alpha: 0.3),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: const Icon(
            Icons.fingerprint,
            size: 48,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: CertiliaTheme.spaceLG),
        Text(
          'Certilia SDK',
          style: CertiliaTextStyles.heading(isDark),
        ),
        const SizedBox(height: CertiliaTheme.spaceXS),
        Text(
          isEnglish
              ? 'Secure Authentication Demo'
              : 'Demonstracija Sigurne Prijave',
          style: CertiliaTextStyles.bodyMedium(isDark).copyWith(
            color: CertiliaTheme.textSecondaryColor(isDark),
          ),
        ),
      ],
    );
  }

  Widget _buildLoginCard(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 400),
      decoration: BoxDecoration(
        color: CertiliaTheme.surfaceColor(isDark),
        borderRadius: BorderRadius.circular(CertiliaTheme.radiusLarge),
        boxShadow: CertiliaTheme.cardShadow(isDark),
      ),
      padding: const EdgeInsets.all(CertiliaTheme.spaceLG),
      child: Column(
        children: [
          // Error message if any
          if (errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(CertiliaTheme.spaceMD),
              decoration: BoxDecoration(
                color: CertiliaTheme.errorRed.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(CertiliaTheme.radiusMedium),
                border: Border.all(
                  color: CertiliaTheme.errorRed.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    color: CertiliaTheme.errorRed,
                    size: 20,
                  ),
                  const SizedBox(width: CertiliaTheme.spaceMD),
                  Expanded(
                    child: Text(
                      errorMessage!,
                      style: CertiliaTextStyles.bodySmall(isDark).copyWith(
                        color: CertiliaTheme.errorRed,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: CertiliaTheme.spaceLG),
          ],

          // Welcome text
          Text(
            isEnglish ? 'Welcome' : 'Dobrodošli',
            style: CertiliaTextStyles.subheading(isDark),
          ),
          const SizedBox(height: CertiliaTheme.spaceSM),
          Text(
            isEnglish
                ? 'Sign in with your Croatian eID card'
                : 'Prijavite se s vašom eOsobnom iskaznicom',
            style: CertiliaTextStyles.bodySmall(isDark),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: CertiliaTheme.spaceLG),

          // Login button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: onAuthenticate,
              style: ElevatedButton.styleFrom(
                backgroundColor: CertiliaTheme.primaryBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(CertiliaTheme.radiusMedium),
                ),
                elevation: 2,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.login, size: 20),
                  const SizedBox(width: CertiliaTheme.spaceMD),
                  Text(
                    isEnglish ? 'Login with Certilia' : 'Prijava s Certilia',
                    style: CertiliaTextStyles.button,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: CertiliaTheme.spaceLG),

          // Info text
          Container(
            padding: const EdgeInsets.all(CertiliaTheme.spaceMD),
            decoration: BoxDecoration(
              color: CertiliaTheme.surfaceGrayColor(isDark),
              borderRadius: BorderRadius.circular(CertiliaTheme.radiusSmall),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 20,
                  color: CertiliaTheme.textSecondaryColor(isDark),
                ),
                const SizedBox(width: CertiliaTheme.spaceMD),
                Expanded(
                  child: Text(
                    isEnglish
                        ? 'This demo uses NIAS authentication system'
                        : 'Ova demonstracija koristi NIAS sustav autentifikacije',
                    style: CertiliaTextStyles.bodySmall(isDark),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Language toggle
        TextButton.icon(
          onPressed: onToggleLanguage,
          icon: Icon(
            Icons.language,
            size: 20,
            color: CertiliaTheme.textSecondaryColor(isDark),
          ),
          label: Text(
            isEnglish ? 'Hrvatski' : 'English',
            style: CertiliaTextStyles.bodySmall(isDark),
          ),
        ),

        if (onThemeToggle != null) ...[
          const SizedBox(width: CertiliaTheme.spaceMD),
          // Theme toggle
          IconButton(
            onPressed: onThemeToggle,
            icon: Icon(
              isDark ? Icons.light_mode : Icons.dark_mode,
              color: CertiliaTheme.textSecondaryColor(isDark),
            ),
            tooltip: isDark ? 'Light mode' : 'Dark mode',
          ),
        ],
      ],
    );
  }
}