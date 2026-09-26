import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_certilia/flutter_certilia.dart';
import 'certilia_auth/certilia_auth_widget.dart';
import 'certilia_auth/theme/certilia_theme.dart';

/// URL of the certilia-server proxy. Override at build time:
///   flutter run -d chrome --dart-define=CERTILIA_SERVER_URL=https://your.proxy.example
///
/// The default is the ngrok tunnel used during development.
const _defaultServerUrl = 'https://uniformly-credible-opossum.ngrok-free.app';
const _serverUrl = String.fromEnvironment(
  'CERTILIA_SERVER_URL',
  defaultValue: _defaultServerUrl,
);

/// Where Certilia redirects after login, when the app receives the redirect
/// itself (see `CertiliaConfig.callbackUrl`). Empty: the in-app WebView on
/// mobile, the example's own callback page on web.
///   Android custom scheme: --dart-define=CERTILIA_CALLBACK_URL=hr.example.app:1/callback
///   Web / App Link:        --dart-define=CERTILIA_CALLBACK_URL=https://app.example/certilia_callback.html
const _callbackUrl = String.fromEnvironment('CERTILIA_CALLBACK_URL');

/// On web the SDK requires a callback page; default to the example's own
/// web/certilia_callback.html next to index.html. Register that URL as the
/// Certilia client's callback.
String? get _effectiveCallbackUrl {
  if (_callbackUrl.isNotEmpty) return _callbackUrl;
  if (kIsWeb) return Uri.base.resolve('certilia_callback.html').toString();
  return null;
}

/// Direct mode, no certilia-server: the app holds the Certilia client and
/// talks to Certilia itself. Needs an https CERTILIA_CALLBACK_URL. The secret
/// is compiled into the app, where anyone can read it; see the README.
///   --dart-define=CERTILIA_CLIENT_ID=... --dart-define=CERTILIA_CLIENT_SECRET=...
const _clientId = String.fromEnvironment('CERTILIA_CLIENT_ID');
const _clientSecret = String.fromEnvironment('CERTILIA_CLIENT_SECRET');

const _scopes = ['openid', 'profile', 'eid', 'email', 'offline_access'];

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.dark;

  void _toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.light
          ? ThemeMode.dark
          : ThemeMode.light;
    });
  }

  CertiliaAuthWidget _buildAuthWidget() {
    return CertiliaAuthWidget(
      serverUrl: _serverUrl,
      direct: _clientId.isEmpty
          ? null
          : const CertiliaDirectClient(
              clientId: _clientId,
              clientSecret: _clientSecret,
            ),
      callbackUrl: _effectiveCallbackUrl,
      scopes: _scopes,
      enableLogging: true,
      onThemeToggle: _toggleTheme,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Certilia SDK Example',
      theme: CertiliaTheme.lightTheme,
      darkTheme: CertiliaTheme.darkTheme,
      themeMode: _themeMode,
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      routes: {'/': (context) => _buildAuthWidget()},
      onUnknownRoute: (settings) => MaterialPageRoute(
        builder: (context) => _buildAuthWidget(),
      ),
    );
  }
}
