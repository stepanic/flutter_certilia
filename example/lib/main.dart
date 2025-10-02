import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_certilia/flutter_certilia.dart';
// ignore: implementation_imports
import 'package:flutter_certilia/src/certilia_stateful_wrapper.dart';
// ignore: implementation_imports
import 'package:flutter_certilia/src/certilia_webview_client.dart';
// ignore: implementation_imports
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

/// Main stateless auth view wrapper with language state
class _StatelessAuthView extends StatefulWidget {
  final VoidCallback onThemeToggle;
  final bool hasStoredToken;
  final CertiliaUser? storedUser;

  const _StatelessAuthView({
    required this.onThemeToggle,
    required this.hasStoredToken,
    this.storedUser,
  });

  @override
  State<_StatelessAuthView> createState() => _StatelessAuthViewState();
}

class _StatelessAuthViewState extends State<_StatelessAuthView> {
  bool _isEnglish = false;
  CertiliaExtendedInfo? _extendedInfo;
  bool _isLoadingExtendedInfo = false;

  @override
  void initState() {
    super.initState();
    _checkAndLoadData();
  }

  Future<void> _checkAndLoadData() async {
    // Check if we have stored token and load data if we do
    final accessToken = await CertiliaStatefulWrapper.getStoredAccessToken();

    // Automatically fetch extended info if we have a valid token
    if (accessToken != null && mounted) {
      _fetchExtendedInfoSilently();
    }
  }

  Future<void> _fetchExtendedInfoSilently() async {
    setState(() {
      _isLoadingExtendedInfo = true;
    });

    try {
      final token = await CertiliaStatefulWrapper.getStoredAccessToken();
      if (token == null) return;

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

      var extendedInfo = await client.getExtendedUserInfo(token);

      // If we got minimal data (less than 10 fields), try to get full user info
      // This happens after token refresh when JWT doesn't contain all claims
      if (extendedInfo != null && extendedInfo.availableFields.length < 10) {
        debugPrint('Extended info has only ${extendedInfo.availableFields.length} fields, fetching full user info...');

        try {
          // Get basic user info which calls the userinfo endpoint
          final userInfo = await client.getUserInfo(token);

          if (userInfo != null) {
            // Merge user info into extended info
            final mergedData = Map<String, dynamic>.from(extendedInfo.userInfo);

            // Add user info fields
            mergedData['given_name'] = userInfo.firstName;
            mergedData['family_name'] = userInfo.lastName;
            mergedData['first_name'] = userInfo.firstName;
            mergedData['last_name'] = userInfo.lastName;
            mergedData['email'] = userInfo.email;
            mergedData['oib'] = userInfo.oib;
            if (userInfo.dateOfBirth != null) {
              mergedData['birthdate'] = userInfo.dateOfBirth!.toIso8601String().split('T')[0];
              mergedData['date_of_birth'] = userInfo.dateOfBirth!.toIso8601String().split('T')[0];
            }

            // Create new extended info with merged data
            extendedInfo = CertiliaExtendedInfo(
              userInfo: mergedData,
              availableFields: mergedData.keys.where((key) =>
                mergedData[key] != null && mergedData[key].toString().isNotEmpty
              ).toList(),
            );

            debugPrint('Merged info now has ${extendedInfo.availableFields.length} fields');
          }
        } catch (e) {
          debugPrint('Failed to fetch basic user info: $e');
        }
      }

      client.dispose();

      if (mounted) {
        setState(() {
          _extendedInfo = extendedInfo;
          _isLoadingExtendedInfo = false;
        });
      }
    } catch (e) {
      debugPrint('Failed to fetch extended info: $e');
      if (mounted) {
        setState(() {
          _isLoadingExtendedInfo = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: CertiliaTheme.backgroundColor(isDark),
      body: Column(
        children: [
          _buildHeader(isDark),
          Expanded(
            child: widget.hasStoredToken && widget.storedUser != null
                ? _buildAuthenticatedView(context, widget.storedUser!, isDark, _isEnglish)
                : _buildUnauthenticatedView(context, isDark, _isEnglish),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
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
                _buildLanguageToggle(isDark),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Build language toggle button group
  Widget _buildLanguageToggle(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: CertiliaTheme.borderColor(isDark)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          _buildLanguageButton('HR', !_isEnglish, isDark, isFirst: true),
          Container(
            width: 1,
            height: 24,
            color: CertiliaTheme.borderColor(isDark),
          ),
          _buildLanguageButton('EN', _isEnglish, isDark, isLast: true),
        ],
      ),
    );
  }

  /// Build individual language button
  Widget _buildLanguageButton(
    String label,
    bool isActive,
    bool isDark, {
    bool isFirst = false,
    bool isLast = false,
  }) {
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
              _buildUserAvatar(user, isDark),
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
          Text(
            isEnglish ? 'Extended Information' : 'Proširene informacije',
            style: CertiliaTextStyles.subheading(isDark),
          ),
          const SizedBox(height: CertiliaTheme.spaceMD),

          if (_extendedInfo == null && !_isLoadingExtendedInfo)
            Text(
              isEnglish
                ? 'Extended information will be loaded automatically.'
                : 'Proširene informacije će biti automatski učitane.',
              style: CertiliaTextStyles.bodySmall(isDark).copyWith(
                color: CertiliaTheme.textSecondaryColor(isDark),
              ),
            )
          else if (_isLoadingExtendedInfo && _extendedInfo == null)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Column(
                  children: [
                    CircularProgressIndicator(
                      color: CertiliaTheme.primaryBlue,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      isEnglish ? 'Loading...' : 'Učitavanje...',
                      style: CertiliaTextStyles.bodySmall(isDark),
                    ),
                  ],
                ),
              ),
            )
          else if (_extendedInfo != null)
            _buildExtendedInfoList(isDark, isEnglish),
        ],
      ),
    );
  }

  Widget _buildExtendedInfoList(bool isDark, bool isEnglish) {
    final info = _extendedInfo!;
    final thumbnail = info.getField('thumbnail') as String?;
    final profilePhoto = info.getField('profile_photo') as String?;
    final photo = info.getField('photo') as String?;

    // Try to get any available image
    final imageBase64 = thumbnail ?? profilePhoto ?? photo;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Profile image if available
        if (imageBase64 != null && imageBase64.isNotEmpty) ...[
          Center(
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: CertiliaTheme.borderColor(isDark),
                  width: 2,
                ),
              ),
              child: ClipOval(
                child: _buildProfileImage(imageBase64, isDark),
              ),
            ),
          ),
          const SizedBox(height: CertiliaTheme.spaceLG),
        ],

        // Display all available fields
        ...info.availableFields.map((field) {
          final value = info.getField(field);

          // Skip image fields as we display them separately
          if (field == 'thumbnail' || field == 'profile_photo' || field == 'photo') {
            return const SizedBox.shrink();
          }

          // Skip null or empty values
          if (value == null || value.toString().isEmpty) {
            return const SizedBox.shrink();
          }

          return Column(
            children: [
              Divider(
                color: CertiliaTheme.dividerColor(isDark),
                height: 1,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        _formatFieldName(field),
                        style: CertiliaTextStyles.labelSmall(isDark),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 3,
                      child: SelectableText(
                        _formatFieldValue(value),
                        style: CertiliaTextStyles.bodyMedium(isDark),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        }).toList(),
      ],
    );
  }

  Widget _buildProfileImage(String base64Image, bool isDark) {
    try {
      // Remove data:image/jpeg;base64, prefix if present
      final cleanBase64 = base64Image.replaceAll(RegExp(r'data:image/[^;]+;base64,'), '');
      final bytes = base64Decode(cleanBase64);

      return Image.memory(
        bytes,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildImagePlaceholder(isDark);
        },
      );
    } catch (e) {
      debugPrint('Error decoding profile image: $e');
      return _buildImagePlaceholder(isDark);
    }
  }

  Widget _buildImagePlaceholder(bool isDark) {
    return Container(
      color: CertiliaTheme.surfaceColor(isDark),
      child: Icon(
        Icons.person,
        size: 60,
        color: CertiliaTheme.textTertiaryColor(isDark),
      ),
    );
  }

  String _formatFieldName(String field) {
    // Convert snake_case to Title Case
    return field
        .split('_')
        .map((word) => word.isNotEmpty
            ? '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}'
            : '')
        .join(' ');
  }

  String _formatFieldValue(dynamic value) {
    if (value is DateTime) {
      return '${value.day}.${value.month}.${value.year}';
    }
    if (value is bool) {
      return value ? 'Yes' : 'No';
    }
    if (value is List) {
      return value.join(', ');
    }
    if (value is Map) {
      return value.entries.map((e) => '${e.key}: ${e.value}').join(', ');
    }
    return value.toString();
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

}

// Extension methods for _StatelessAuthViewState continue below
extension on _StatelessAuthViewState {
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

  Widget _buildUserAvatar(CertiliaUser user, bool isDark) {
    // Check for thumbnail in user.raw data or extended info
    String? thumbnail = user.raw['thumbnail'] as String?;

    // If we have extended info, check there too
    if (thumbnail == null && _extendedInfo != null) {
      thumbnail = _extendedInfo!.userInfo['thumbnail'] as String?;
    }

    if (thumbnail != null && thumbnail.isNotEmpty) {
      // Remove data URL prefix if present
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
          ),
        );
      } catch (e) {
        debugPrint('Error decoding thumbnail: $e');
        // Fall through to default avatar
      }
    }

    // Default avatar when no thumbnail is available
    return Container(
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
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text('Initializing...'),
            ],
          ),
        ),
      );

      final certilia = await CertiliaSDKSimple.initialize(
        clientId: '991dffbb1cdd4d51423e1a5de323f13b15256c63',
        serverUrl: 'https://uniformly-credible-opossum.ngrok-free.app',
        scopes: ['openid', 'profile', 'eid', 'email', 'offline_access'],
        enableLogging: true,
      );

      if (!context.mounted) return;

      // Close loading dialog before showing WebView
      Navigator.pop(context);

      // Small delay to ensure dialog is closed
      await Future.delayed(const Duration(milliseconds: 100));

      if (!context.mounted) return;

      // Now show the WebView for authentication
      await certilia.authenticate(context);

      if (!context.mounted) return;

      // Small delay to ensure any dialogs from authentication are closed
      await Future.delayed(const Duration(milliseconds: 200));

      if (!context.mounted) return;

      // Refresh the page to show authenticated state
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => HomePage(onThemeToggle: widget.onThemeToggle),
        ),
      );
    } on CertiliaAuthenticationException catch (e) {
      // User cancelled or authentication failed
      if (!context.mounted) return;

      // Check if dialog is still open and close it
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      // Only show error if it's not a cancellation
      if (!e.message.toLowerCase().contains('cancel') &&
          !e.message.toLowerCase().contains('dismissed')) {
        _showErrorDialog(context, 'Authentication failed: ${e.message}');
      }
    } catch (e) {
      if (!context.mounted) return;

      // Check if dialog is still open and close it
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      _showErrorDialog(context, 'Error: $e');
    }
  }



  Future<void> _logout(BuildContext context) async {
    // Clear all stored authentication data
    await CertiliaStatefulWrapper.clearStoredData();

    if (!context.mounted) return;

    // Clear state variables
    // ignore: invalid_use_of_protected_member
    setState(() {
      _extendedInfo = null;
      _isLoadingExtendedInfo = false;
    });

    // Refresh the page to show unauthenticated state
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => HomePage(onThemeToggle: widget.onThemeToggle),
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

  // Themes
  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    primaryColor: primaryBlue,
    scaffoldBackgroundColor: lightBackground,
    colorScheme: const ColorScheme.light(
      primary: primaryBlue,
      secondary: successGreen,
      error: errorRed,
      surface: lightSurface,
    ),
  );

  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    primaryColor: primaryBlue,
    scaffoldBackgroundColor: darkBackground,
    colorScheme: const ColorScheme.dark(
      primary: primaryBlue,
      secondary: successGreen,
      error: errorRed,
      surface: darkSurface,
    ),
  );
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