import '../models/certilia_config.dart';
import 'certilia_auth_backend.dart';
import 'certilia_logger.dart';
import 'direct_auth_service.dart';
import 'proxy_auth_service.dart';

/// The backend [config] asks for: Certilia directly when
/// [CertiliaConfig.direct] is set, otherwise the proxy at [serverUrl].
CertiliaAuthBackend createAuthBackend({
  required CertiliaConfig config,
  required String serverUrl,
  required String componentName,
}) {
  final logger = CertiliaLogger(
    componentName: '$componentName.backend',
    enableLogging: config.enableLogging,
  );
  final direct = config.direct;
  if (direct != null) {
    return DirectAuthService(client: direct, scopes: config.scopes, logger: logger);
  }
  return ProxyAuthService(serverUrl: serverUrl, logger: logger);
}
