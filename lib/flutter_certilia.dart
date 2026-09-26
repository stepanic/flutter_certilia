/// flutter_certilia: Login with Certilia (Croatian eID via NIAS) for Flutter.
///
/// The Flutter client talks to your backend proxy (`certilia-server`), which
/// holds the Certilia client secret, or in direct mode to Certilia itself.
/// See README.
library;

// Primary SDK entry point (public API)
export 'src/certilia_sdk.dart';

// Public models
export 'src/models/certilia_user.dart';
export 'src/models/certilia_config.dart';
export 'src/models/certilia_direct_client.dart';
export 'src/models/certilia_token.dart';
export 'src/models/certilia_extended_info.dart';

// Public exceptions
export 'src/exceptions/certilia_exception.dart';
