import 'exceptions/certilia_exception.dart';

/// Extracts the authorization code from a callback URL.
///
/// Throws [CertiliaAuthenticationException] when the user cancelled
/// ([callback] is null), when Certilia returned an OAuth error, when the
/// `state` does not match the one from `/api/auth/initialize`, or when the
/// code is missing.
String codeFromCallback(Uri? callback, {required String expectedState}) {
  if (callback == null) {
    throw const CertiliaAuthenticationException(
      message: 'Authentication was cancelled',
    );
  }
  final params = callback.queryParameters;
  final error = params['error'];
  if (error != null) {
    throw CertiliaAuthenticationException(
      message: params['error_description'] ?? 'Certilia returned an error',
      code: error,
    );
  }
  if (params['state'] != expectedState) {
    throw const CertiliaAuthenticationException(
      message: 'State mismatch in the authorization callback',
      code: 'state_mismatch',
    );
  }
  final code = params['code'];
  if (code == null || code.isEmpty) {
    throw const CertiliaAuthenticationException(
      message: 'No authorization code in the callback',
      code: 'missing_code',
    );
  }
  return code;
}
