import 'models/certilia_config.dart';

/// Stub of the web factory for the other platforms, where
/// [CertiliaSDK.initialize] never calls it.
dynamic createWebClient({
  required CertiliaConfig config,
  required String serverUrl,
}) {
  throw UnsupportedError(
    'Web client is not available on this platform. '
    'This should not be called on non-web platforms.',
  );
}