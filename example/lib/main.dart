import 'package:flutter/material.dart';
import 'certilia_auth/certilia_auth_widget.dart';
import 'certilia_auth/theme/certilia_theme.dart';

/// URL of the certilia-server proxy. Override at build time:
///   flutter run -d chrome --dart-define=CERTILIA_SERVER_URL=https://your.proxy.example
///
/// The default points at the dev ngrok tunnel used during development.
const _defaultServerUrl = 'https://uniformly-credible-opossum.ngrok-free.app';
const _serverUrl = String.fromEnvironment(
  'CERTILIA_SERVER_URL',
  defaultValue: _defaultServerUrl,
);

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
