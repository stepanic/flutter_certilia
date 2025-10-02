// Primary SDK entry points (public API)
export 'src/certilia_sdk_simple.dart'; // Recommended entry point
export 'src/certilia_sdk.dart'; // Advanced configuration

// Legacy client (deprecated - will be removed in v1.0.0)
export 'src/certilia_client.dart';

// Public models
export 'src/models/certilia_user.dart';
export 'src/models/certilia_config.dart';
export 'src/models/certilia_config_simple.dart';
export 'src/models/certilia_token.dart';
export 'src/models/certilia_extended_info.dart';

// Public exceptions
export 'src/exceptions/certilia_exception.dart';

// Note: Internal client implementations are no longer exported
// These are implementation details that should not be used directly:
// - certilia_webview_client.dart
// - certilia_web_client.dart
// - certilia_universal_client.dart
// - certilia_appauth_client.dart
// - certilia_manual_oauth_client.dart