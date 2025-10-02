import 'package:flutter/material.dart';

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