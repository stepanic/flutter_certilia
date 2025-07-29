import 'certilia_web_client.dart';
import 'models/certilia_config.dart';

/// Factory function for web platform
/// This implementation is used when on web platform
dynamic createWebClient({
  required CertiliaConfig config,
  required String serverUrl,
}) {
  return CertiliaWebClient(
    config: config,
    serverUrl: serverUrl,
  );
}