import 'package:flutter/material.dart';
import 'package:flutter_certilia/flutter_certilia.dart';
import '../theme/certilia_theme.dart';

/// Card widget displaying extended user information
class ExtendedInfoCard extends StatelessWidget {
  final CertiliaExtendedInfo? extendedInfo;
  final bool isLoading;
  final bool isDark;
  final bool isEnglish;

  const ExtendedInfoCard({
    super.key,
    this.extendedInfo,
    required this.isLoading,
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
                Icons.info_outline,
                color: CertiliaTheme.primaryBlue,
                size: 24,
              ),
              const SizedBox(width: CertiliaTheme.spaceMD),
              Text(
                isEnglish ? 'Extended Information' : 'Prošireni Podaci',
                style: CertiliaTextStyles.subheading(isDark),
              ),
              const Spacer(),
              if (isLoading)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: CertiliaTheme.primaryBlue,
                  ),
                ),
            ],
          ),
          const SizedBox(height: CertiliaTheme.spaceLG),

          // Content
          if (isLoading && extendedInfo == null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(CertiliaTheme.spaceLG),
                child: Column(
                  children: [
                    CircularProgressIndicator(
                      color: CertiliaTheme.primaryBlue,
                    ),
                    const SizedBox(height: CertiliaTheme.spaceMD),
                    Text(
                      isEnglish ? 'Loading extended data...' : 'Učitavanje proširenih podataka...',
                      style: CertiliaTextStyles.bodySmall(isDark),
                    ),
                  ],
                ),
              ),
            )
          else if (extendedInfo != null)
            _buildExtendedInfo()
          else
            _buildNoDataMessage(),
        ],
      ),
    );
  }

  Widget _buildExtendedInfo() {
    final fields = extendedInfo!.availableFields;

    if (fields.isEmpty) {
      return _buildNoDataMessage();
    }

    // Filter out fields that are already shown in basic info
    final excludedFields = ['sub', 'given_name', 'family_name', 'email', 'oib', 'birthdate', 'thumbnail'];
    final additionalFields = fields.where((field) => !excludedFields.contains(field)).toList();

    if (additionalFields.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(CertiliaTheme.spaceMD),
        decoration: BoxDecoration(
          color: CertiliaTheme.surfaceGrayColor(isDark),
          borderRadius: BorderRadius.circular(CertiliaTheme.radiusSmall),
        ),
        child: Row(
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 20,
              color: CertiliaTheme.successGreen,
            ),
            const SizedBox(width: CertiliaTheme.spaceMD),
            Expanded(
              child: Text(
                isEnglish
                    ? 'All available data is shown in user information'
                    : 'Svi dostupni podaci prikazani su u korisničkim informacijama',
                style: CertiliaTextStyles.bodySmall(isDark),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Available fields count
        Container(
          padding: const EdgeInsets.all(CertiliaTheme.spaceSM),
          decoration: BoxDecoration(
            color: CertiliaTheme.primaryBlue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(CertiliaTheme.radiusSmall),
          ),
          child: Text(
            isEnglish
                ? '${additionalFields.length} additional fields available'
                : '${additionalFields.length} dodatnih polja dostupno',
            style: CertiliaTextStyles.labelSmall(isDark).copyWith(
              color: CertiliaTheme.primaryBlue,
            ),
          ),
        ),
        const SizedBox(height: CertiliaTheme.spaceMD),

        // Display additional fields
        ...additionalFields.map((field) {
          final value = extendedInfo!.getField(field);
          if (value != null) {
            return _buildFieldRow(field, value.toString());
          }
          return const SizedBox.shrink();
        }).toList(),
      ],
    );
  }

  Widget _buildNoDataMessage() {
    return Container(
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
                  ? 'No additional data available'
                  : 'Nema dodatnih podataka',
              style: CertiliaTextStyles.bodySmall(isDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldRow(String field, String value) {
    // Get icon and translation for field
    final fieldInfo = _getFieldInfo(field);

    return Padding(
      padding: const EdgeInsets.only(bottom: CertiliaTheme.spaceMD),
      child: Container(
        padding: const EdgeInsets.all(CertiliaTheme.spaceMD),
        decoration: BoxDecoration(
          color: CertiliaTheme.surfaceGrayColor(isDark),
          borderRadius: BorderRadius.circular(CertiliaTheme.radiusSmall),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              fieldInfo['icon'] as IconData,
              size: 20,
              color: CertiliaTheme.primaryBlue,
            ),
            const SizedBox(width: CertiliaTheme.spaceMD),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isEnglish
                      ? fieldInfo['labelEn'] as String
                      : fieldInfo['labelHr'] as String,
                    style: CertiliaTextStyles.labelSmall(isDark),
                  ),
                  if (fieldInfo.containsKey('descEn')) ...[
                    const SizedBox(height: 2),
                    Text(
                      isEnglish
                        ? fieldInfo['descEn'] as String
                        : fieldInfo['descHr'] as String,
                      style: CertiliaTextStyles.bodySmall(isDark).copyWith(
                        fontSize: 11,
                        color: CertiliaTheme.textTertiaryColor(isDark),
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    _formatFieldValue(field, value),
                    style: CertiliaTextStyles.bodyMedium(isDark),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Map<String, dynamic> _getFieldInfo(String field) {
    // Map of field names to icons, translations and descriptions
    final fieldMappings = {
      // Basic user info fields
      'first_name': {
        'icon': Icons.person,
        'labelEn': 'First Name',
        'labelHr': 'Ime',
        'descEn': 'Given name',
        'descHr': 'Osobno ime',
      },
      'last_name': {
        'icon': Icons.person,
        'labelEn': 'Last Name',
        'labelHr': 'Prezime',
        'descEn': 'Family name',
        'descHr': 'Obiteljsko prezime',
      },
      'full_name': {
        'icon': Icons.person,
        'labelEn': 'Full Name',
        'labelHr': 'Puno ime',
        'descEn': 'Complete name',
        'descHr': 'Ime i prezime',
      },
      'given_name': {
        'icon': Icons.person,
        'labelEn': 'Given Name',
        'labelHr': 'Ime',
        'descEn': 'First name',
        'descHr': 'Osobno ime',
      },
      'family_name': {
        'icon': Icons.person,
        'labelEn': 'Family Name',
        'labelHr': 'Prezime',
        'descEn': 'Last name',
        'descHr': 'Obiteljsko prezime',
      },
      'birthdate': {
        'icon': Icons.cake,
        'labelEn': 'Birth Date',
        'labelHr': 'Datum rođenja',
        'descEn': 'Date of birth',
        'descHr': 'Dan rođenja',
      },
      'date_of_birth': {
        'icon': Icons.cake,
        'labelEn': 'Date of Birth',
        'labelHr': 'Datum rođenja',
        'descEn': 'Birth date',
        'descHr': 'Dan rođenja',
      },

      // Contact info
      'email': {
        'icon': Icons.email,
        'labelEn': 'Email',
        'labelHr': 'Email',
        'descEn': 'Email address',
        'descHr': 'Email adresa',
      },
      'mobile': {
        'icon': Icons.smartphone,
        'labelEn': 'Mobile',
        'labelHr': 'Mobitel',
        'descEn': 'Mobile phone number',
        'descHr': 'Broj mobitela',
      },

      // Location info
      'country': {
        'icon': Icons.flag,
        'labelEn': 'Country',
        'labelHr': 'Država',
        'descEn': 'Country of residence',
        'descHr': 'Država prebivališta',
      },
      'formatted': {
        'icon': Icons.home,
        'labelEn': 'Address',
        'labelHr': 'Adresa',
        'descEn': 'Full formatted address',
        'descHr': 'Potpuna formatirana adresa',
      },

      // Personal info
      'gender': {
        'icon': Icons.person,
        'labelEn': 'Gender',
        'labelHr': 'Spol',
        'descEn': 'Gender identity',
        'descHr': 'Spolni identitet',
      },
      'oib': {
        'icon': Icons.badge,
        'labelEn': 'OIB',
        'labelHr': 'OIB',
        'descEn': 'Personal Identification Number',
        'descHr': 'Osobni identifikacijski broj',
      },

      // JWT/OAuth technical fields
      'sub': {
        'icon': Icons.key,
        'labelEn': 'Subject ID',
        'labelHr': 'ID subjekta',
        'descEn': 'Unique user identifier in the system',
        'descHr': 'Jedinstveni identifikator korisnika u sustavu',
      },
      'iss': {
        'icon': Icons.verified_user,
        'labelEn': 'Issuer',
        'labelHr': 'Izdavatelj',
        'descEn': 'Identity provider that issued the token',
        'descHr': 'Pružatelj identiteta koji je izdao token',
      },
      'aud': {
        'icon': Icons.group,
        'labelEn': 'Audience',
        'labelHr': 'Publika',
        'descEn': 'Intended recipient of the token',
        'descHr': 'Namijenjeni primatelj tokena',
      },
      'azp': {
        'icon': Icons.apps,
        'labelEn': 'Authorized Party',
        'labelHr': 'Ovlaštena strana',
        'descEn': 'Client application authorized to use the token',
        'descHr': 'Klijentska aplikacija ovlaštena za korištenje tokena',
      },
      'amr': {
        'icon': Icons.security,
        'labelEn': 'Auth Methods',
        'labelHr': 'Metode autentifikacije',
        'descEn': 'Authentication methods used',
        'descHr': 'Korištene metode provjere identiteta',
      },
      'acr': {
        'icon': Icons.shield,
        'labelEn': 'Auth Context',
        'labelHr': 'Kontekst autentifikacije',
        'descEn': 'Authentication context class reference',
        'descHr': 'Referenca klase konteksta autentifikacije',
      },
      'at_hash': {
        'icon': Icons.fingerprint,
        'labelEn': 'Access Token Hash',
        'labelHr': 'Hash pristupnog tokena',
        'descEn': 'Security hash of the access token',
        'descHr': 'Sigurnosni hash pristupnog tokena',
      },
      'c_hash': {
        'icon': Icons.fingerprint,
        'labelEn': 'Code Hash',
        'labelHr': 'Hash koda',
        'descEn': 'Security hash of the authorization code',
        'descHr': 'Sigurnosni hash autorizacijskog koda',
      },
      'nonce': {
        'icon': Icons.shuffle,
        'labelEn': 'Nonce',
        'labelHr': 'Nonce',
        'descEn': 'Random value to prevent replay attacks',
        'descHr': 'Slučajna vrijednost za sprječavanje napada ponavljanjem',
      },
      'jti': {
        'icon': Icons.tag,
        'labelEn': 'Token ID',
        'labelHr': 'ID tokena',
        'descEn': 'Unique identifier for this token',
        'descHr': 'Jedinstveni identifikator ovog tokena',
      },

      // Additional fields that might appear
      'email_verified': {
        'icon': Icons.verified,
        'labelEn': 'Email Verified',
        'labelHr': 'Email potvrđen',
        'descEn': 'Email verification status',
        'descHr': 'Status potvrde email adrese',
      },
      'phone_number_verified': {
        'icon': Icons.verified,
        'labelEn': 'Phone Verified',
        'labelHr': 'Telefon potvrđen',
        'descEn': 'Phone verification status',
        'descHr': 'Status potvrde telefonskog broja',
      },
    };

    // Check if field exists in mappings
    if (fieldMappings.containsKey(field.toLowerCase())) {
      return fieldMappings[field.toLowerCase()]!;
    }

    // Default fallback - format field name
    final formattedField = field
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) => word.isNotEmpty
            ? '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}'
            : '')
        .join(' ');

    return {
      'icon': Icons.label_outline,
      'labelEn': formattedField,
      'labelHr': formattedField,
      'descEn': 'Additional field',
      'descHr': 'Dodatno polje',
    };
  }

  String _formatFieldValue(String field, String value) {
    // Format boolean values
    if (value.toLowerCase() == 'true' || value.toLowerCase() == 'false') {
      final boolValue = value.toLowerCase() == 'true';
      if (isEnglish) {
        return boolValue ? 'Yes' : 'No';
      } else {
        return boolValue ? 'Da' : 'Ne';
      }
    }

    // Format dates (basic ISO date detection)
    if (RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(value)) {
      try {
        final date = DateTime.parse(value);
        return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
      } catch (_) {
        // If parse fails, return original value
      }
    }

    // Format locale
    if (field.toLowerCase() == 'locale') {
      final localeMap = {
        'hr': isEnglish ? 'Croatian' : 'Hrvatski',
        'en': isEnglish ? 'English' : 'Engleski',
        'hr_HR': isEnglish ? 'Croatian (Croatia)' : 'Hrvatski (Hrvatska)',
        'en_US': isEnglish ? 'English (US)' : 'Engleski (SAD)',
        'en_GB': isEnglish ? 'English (UK)' : 'Engleski (UK)',
      };
      return localeMap[value] ?? value;
    }

    // Format gender
    if (field.toLowerCase() == 'gender') {
      final genderMap = {
        'male': isEnglish ? 'Male' : 'Muško',
        'm': isEnglish ? 'Male' : 'Muško',
        'female': isEnglish ? 'Female' : 'Žensko',
        'f': isEnglish ? 'Female' : 'Žensko',
        'other': isEnglish ? 'Other' : 'Ostalo',
      };
      return genderMap[value.toLowerCase()] ?? value;
    }

    // Format document type
    if (field.toLowerCase() == 'document_type') {
      final docTypeMap = {
        'passport': isEnglish ? 'Passport' : 'Putovnica',
        'id_card': isEnglish ? 'ID Card' : 'Osobna iskaznica',
        'drivers_license': isEnglish ? 'Driver\'s License' : 'Vozačka dozvola',
      };
      return docTypeMap[value.toLowerCase()] ?? value;
    }

    return value;
  }
}