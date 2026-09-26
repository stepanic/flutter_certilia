import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';

import 'certilia_native_client.dart';

/// Opens [url] in the system browser and completes with the callback URL
/// once the browser is redirected to [callbackUrlScheme]. Matches
/// [FlutterWebAuth2.authenticate]; injectable for tests.
typedef WebAuthLauncher = Future<String> Function({
  required String url,
  required String callbackUrlScheme,
  required FlutterWebAuth2Options options,
});

Future<String> _flutterWebAuth2({
  required String url,
  required String callbackUrlScheme,
  required FlutterWebAuth2Options options,
}) =>
    FlutterWebAuth2.authenticate(
      url: url,
      callbackUrlScheme: callbackUrlScheme,
      options: options,
    );

/// Mobile client that runs Certilia's login in the system browser and gets
/// the redirect back through the operating system.
///
/// Android uses Chrome Auth Tab (Custom Tabs on older Chrome), iOS uses
/// ASWebAuthenticationSession. Certilia redirects to
/// [CertiliaConfig.callbackUrl], which is either:
/// - a custom scheme, e.g. `hr.example.app:1/callback`, registered for the
///   app in AndroidManifest.xml / Info.plist; or
/// - an https URL that is an Android App Link / iOS Universal Link for the
///   app (verified through assetlinks.json / apple-app-site-association).
///
/// The code exchange goes through the backend: the proxy, which holds the
/// client secret, or Certilia itself in direct mode.
class CertiliaBrowserClient extends CertiliaNativeClient {
  final WebAuthLauncher _launch;

  CertiliaBrowserClient({
    required super.config,
    required super.serverUrl,
    super.backend,
    WebAuthLauncher? launcher,
  })  : _launch = launcher ?? _flutterWebAuth2,
        super(componentName: 'CertiliaBrowserClient') {
    if (config.callbackUrl == null) {
      throw ArgumentError('CertiliaBrowserClient needs config.callbackUrl');
    }
  }

  Uri get _callback => Uri.parse(config.callbackUrl!);

  @override
  String get redirectUri => config.callbackUrl!;

  /// [CertiliaConfig.preferEphemeralSession] applies to iOS and macOS only.
  ///
  /// There an ephemeral ASWebAuthenticationSession shares no cookies and
  /// skips the "App wants to use certilia.com to sign in" alert. On Android,
  /// flutter_web_auth_2 5.x answers preferEphemeral with a plain Custom Tab
  /// when Chrome is older than 141, and that tab stays on top of the app
  /// after the redirect whenever the user has interacted with the page
  /// (which a Certilia login always involves): the login completes, but the
  /// user has to close Certilia's page by hand. Without preferEphemeral it
  /// launches through AuthTabIntent, Chrome returns the redirect as an
  /// activity result, and the tab closes. Tested on an Android 16 emulator
  /// with Chrome 133, for a custom-scheme and an https App Link callback.
  bool get _preferEphemeral =>
      defaultTargetPlatform == TargetPlatform.iOS ||
              defaultTargetPlatform == TargetPlatform.macOS
          ? config.preferEphemeralSession
          : false;

  @override
  Future<Uri?> obtainCallback(
    BuildContext context,
    String authorizationUrl,
  ) async {
    final callback = _callback;
    final isHttps = callback.scheme == 'https';
    try {
      final result = await _launch(
        url: authorizationUrl,
        callbackUrlScheme: callback.scheme,
        options: FlutterWebAuth2Options(
          preferEphemeral: _preferEphemeral,
          httpsHost: isHttps ? callback.host : null,
          httpsPath: isHttps ? callback.path : null,
        ),
      );
      return Uri.parse(result);
    } on PlatformException catch (e) {
      if (e.code == 'CANCELED') {
        logger.log('User closed the browser before finishing');
        return null;
      }
      rethrow;
    }
  }
}
