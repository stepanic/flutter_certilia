import 'exceptions/certilia_exception.dart';

/// Whether a failed token refresh means the session is over, as opposed to
/// a failure that a later attempt can get past.
///
/// Certilia (direct mode) answers a refused refresh token with an OAuth
/// error, which the SDK reports as [CertiliaAuthenticationException]. The
/// proxy answers with 400, 401 or 403. Timeouts, 5xx responses and
/// connection errors leave the stored session in place.
bool refreshWasRefused(Object error) {
  if (error is CertiliaAuthenticationException) return true;
  if (error is CertiliaNetworkException) {
    final status = error.statusCode;
    return status == 400 || status == 401 || status == 403;
  }
  return false;
}
