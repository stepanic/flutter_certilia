import 'certilia_web_client.dart';
import 'models/certilia_config.dart';

/// Builds the web client; `certilia_sdk.dart` imports this file on web.
dynamic createWebClient({
  required CertiliaConfig config,
  required String serverUrl,
}) {
  return CertiliaWebClient(
    config: config,
    serverUrl: serverUrl,
  );
}