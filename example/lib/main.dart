import 'package:flutter/material.dart';
import 'certilia_auth/certilia_auth_widget.dart';
import 'certilia_auth/theme/certilia_theme.dart';

void main() {
  runApp(const MyApp());
}

/// Main application widget
///
/// This is a minimal wrapper that provides theme management
/// and hosts the standalone CertiliaAuthWidget
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // Default to dark theme
  ThemeMode _themeMode = ThemeMode.dark;

  void _toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.light
          ? ThemeMode.dark
          : ThemeMode.light;
    });
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
      routes: {
        '/': (context) => CertiliaAuthWidget(
          // Configuration
          clientId: '991dffbb1cdd4d51423e1a5de323f13b15256c63',
          serverUrl: 'https://uniformly-credible-opossum.ngrok-free.app',
          scopes: const ['openid', 'profile', 'eid', 'email', 'offline_access'],
          enableLogging: true,
          // Theme toggle callback
          onThemeToggle: _toggleTheme,
        ),
      },
      // Fallback route to ensure Navigator always has something
      onUnknownRoute: (settings) {
        return MaterialPageRoute(
          builder: (context) => CertiliaAuthWidget(
            clientId: '991dffbb1cdd4d51423e1a5de323f13b15256c63',
            serverUrl: 'https://uniformly-credible-opossum.ngrok-free.app',
            scopes: const ['openid', 'profile', 'eid', 'email', 'offline_access'],
            enableLogging: true,
            onThemeToggle: _toggleTheme,
          ),
        );
      },
    );
  }
}