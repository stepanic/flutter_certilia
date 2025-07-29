import 'models/certilia_config.dart';

/// Factory function for non-web platforms
/// This stub is used when not on web platform
dynamic createWebClient({
  required CertiliaConfig config,
  required String serverUrl,
}) {
  throw UnsupportedError(
    'Web client is not available on this platform. '
    'This should not be called on non-web platforms.',
  );
}