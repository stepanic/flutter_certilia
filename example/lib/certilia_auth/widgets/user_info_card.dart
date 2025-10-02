import 'package:flutter/material.dart';
import 'package:flutter_certilia/flutter_certilia.dart';
import '../theme/certilia_theme.dart';

/// Card widget displaying basic user information
class UserInfoCard extends StatelessWidget {
  final CertiliaUser user;
  final bool isDark;
  final bool isEnglish;

  const UserInfoCard({
    super.key,
    required this.user,
    required this.isDark,
    required this.isEnglish,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: CertiliaTheme.surfaceColor(isDark),
        borderRadius: BorderRadius.circular(CertiliaTheme.radiusLarge),
        boxShadow: CertiliaTheme.cardShadow(isDark),
      ),
      padding: const EdgeInsets.all(CertiliaTheme.spaceLG),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(
                Icons.person_outline,
                color: CertiliaTheme.primaryBlue,
                size: 24,
              ),
              const SizedBox(width: CertiliaTheme.spaceMD),
              Text(
                isEnglish ? 'User Information' : 'Korisnički Podaci',
                style: CertiliaTextStyles.subheading(isDark),
              ),
            ],
          ),
          const SizedBox(height: CertiliaTheme.spaceLG),

          // User data
          if (user.fullName != null)
            _buildInfoRow(
              Icons.badge_outlined,
              isEnglish ? 'Full Name' : 'Puno Ime',
              user.fullName!,
            ),

          if (user.email != null)
            _buildInfoRow(
              Icons.email_outlined,
              isEnglish ? 'Email' : 'Email',
              user.email!,
            ),

          if (user.oib != null)
            _buildInfoRow(
              Icons.credit_card,
              'OIB',
              user.oib!,
            ),

          if (user.dateOfBirth != null)
            _buildInfoRow(
              Icons.cake_outlined,
              isEnglish ? 'Date of Birth' : 'Datum Rođenja',
              _formatDate(user.dateOfBirth!),
            ),

          if (user.sub != null)
            _buildInfoRow(
              Icons.fingerprint,
              isEnglish ? 'User ID' : 'Korisnički ID',
              user.sub,
            ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
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

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }
}