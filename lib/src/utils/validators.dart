/// Utility class for validation functions
class Validators {
  Validators._();

  /// Validates if a string is a valid URL
  static bool isValidUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (_) {
      return false;
    }
  }

  /// Validates if a string is a valid redirect URL
  static bool isValidRedirectUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && uri.scheme.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Validates if a string is a valid OIB (Croatian tax number)
  static bool isValidOib(String? oib) {
    if (oib == null || oib.length != 11) return false;
    
    // Check if all characters are digits
    if (!RegExp(r'^\d{11}$').hasMatch(oib)) return false;
    
    // OIB checksum validation using ISO 7064 MOD 11,10
    int a = 10;
    for (int i = 0; i < 10; i++) {
      a = (a + int.parse(oib[i])) % 10;
      if (a == 0) a = 10;
      a = (a * 2) % 11;
    }
    
    final checkDigit = 11 - a;
    final controlNumber = checkDigit == 10 ? 0 : checkDigit;
    return controlNumber == int.parse(oib[10]);
  }

  /// Validates if a string is a valid email
  static bool isValidEmail(String? email) {
    if (email == null || email.isEmpty) return false;
    
    // Basic email validation
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    
    return emailRegex.hasMatch(email);
  }

  /// Validates OAuth scopes
  static bool areValidScopes(List<String> scopes) {
    if (scopes.isEmpty) return false;
    
    for (final scope in scopes) {
      if (scope.isEmpty || scope.contains(' ')) {
        return false;
      }
    }
    
    return true;
  }
}