import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_certilia/flutter_certilia.dart';
import '../theme/certilia_theme.dart';
import 'user_info_card.dart';
import 'extended_info_card.dart';

/// Authenticated view widget for logged-in users
class AuthenticatedView extends StatelessWidget {
  final bool isDark;
  final bool isEnglish;
  final CertiliaUser user;
  final CertiliaExtendedInfo? extendedInfo;
  final bool isLoadingExtendedInfo;
  final VoidCallback onLogout;
  final VoidCallback onToggleLanguage;
  final VoidCallback? onThemeToggle;

  const AuthenticatedView({
    super.key,
    required this.isDark,
    required this.isEnglish,
    required this.user,
    this.extendedInfo,
    required this.isLoadingExtendedInfo,
    required this.onLogout,
    required this.onToggleLanguage,
    this.onThemeToggle,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(CertiliaTheme.spaceLG),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),
            const SizedBox(height: CertiliaTheme.spaceLG),
            UserInfoCard(
              user: user,
              isDark: isDark,
              isEnglish: isEnglish,
            ),
            const SizedBox(height: CertiliaTheme.spaceLG),
            ExtendedInfoCard(
              extendedInfo: extendedInfo,
              isLoading: isLoadingExtendedInfo,
              isDark: isDark,
              isEnglish: isEnglish,
            ),
            const SizedBox(height: CertiliaTheme.spaceLG),
            _buildActionButtons(),
            const SizedBox(height: CertiliaTheme.spaceLG),
            _buildControlButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        // User avatar
        _buildUserAvatar(),
        const SizedBox(width: CertiliaTheme.spaceMD),
        // Welcome text
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isEnglish ? 'Welcome back' : 'Dobrodošli natrag',
                style: CertiliaTextStyles.bodySmall(isDark),
              ),
              const SizedBox(height: 4),
              Text(
                user.fullName ?? user.email ?? 'User',
                style: CertiliaTextStyles.subheading(isDark),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        // Theme toggle
        if (onThemeToggle != null)
          IconButton(
            onPressed: onThemeToggle,
            icon: Icon(
              isDark ? Icons.light_mode : Icons.dark_mode,
              color: CertiliaTheme.textSecondaryColor(isDark),
            ),
            tooltip: isDark ? 'Light mode' : 'Dark mode',
          ),
      ],
    );
  }

  Widget _buildUserAvatar() {
    // Check for thumbnail in user data or extended info
    String? thumbnail = user.raw['thumbnail'] as String?;
    if (thumbnail == null && extendedInfo != null) {
      thumbnail = extendedInfo!.getField('thumbnail') as String?;
    }

    if (thumbnail != null && thumbnail.isNotEmpty) {
      // Handle base64 thumbnail
      String base64String = thumbnail;
      if (thumbnail.contains(',')) {
        base64String = thumbnail.split(',')[1];
      }

      try {
        final bytes = base64Decode(base64String);
        return Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            image: DecorationImage(
              image: MemoryImage(bytes),
              fit: BoxFit.cover,
            ),
            boxShadow: CertiliaTheme.cardShadow(isDark),
          ),
        );
      } catch (e) {
        // Fall through to default avatar
      }
    }

    // Default avatar with initials
    final initials = _getInitials(user.fullName ?? user.email ?? 'U');
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: CertiliaTheme.primaryBlue,
        borderRadius: BorderRadius.circular(12),
        boxShadow: CertiliaTheme.cardShadow(isDark),
      ),
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, 1).toUpperCase();
  }

  Widget _buildActionButtons() {
    return Center(
      child: SizedBox(
        width: 200,
        child: ElevatedButton.icon(
          onPressed: onLogout,
          style: ElevatedButton.styleFrom(
            backgroundColor: CertiliaTheme.errorRed.withValues(alpha: 0.1),
            foregroundColor: CertiliaTheme.errorRed,
            elevation: 0,
            padding: const EdgeInsets.symmetric(
              horizontal: CertiliaTheme.spaceLG,
              vertical: CertiliaTheme.spaceMD,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(CertiliaTheme.radiusMedium),
              side: BorderSide(
                color: CertiliaTheme.errorRed.withValues(alpha: 0.3),
              ),
            ),
          ),
          icon: const Icon(Icons.logout, size: 20),
          label: Text(
            isEnglish ? 'Logout' : 'Odjava',
            style: CertiliaTextStyles.button,
          ),
        ),
      ),
    );
  }

  Widget _buildControlButtons() {
    return Center(
      child: TextButton.icon(
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
    );
  }
}