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
          // Configuration - Replace these with your actual values
          clientId: 'YOUR_CLIENT_ID_HERE',
          serverUrl: 'https://your-backend-server.com',
          scopes: const ['openid', 'profile', 'eid', 'email', 'offline_access'],
          enableLogging: false, // Set to true for development
          // Theme toggle callback
          onThemeToggle: _toggleTheme,
        ),
      },
      // Fallback route to ensure Navigator always has something
      onUnknownRoute: (settings) {
        return MaterialPageRoute(
          builder: (context) => CertiliaAuthWidget(
            clientId: 'YOUR_CLIENT_ID_HERE',
            serverUrl: 'https://your-backend-server.com',
            scopes: const ['openid', 'profile', 'eid', 'email', 'offline_access'],
            enableLogging: false,
            onThemeToggle: _toggleTheme,
          ),
        );
      },
    );
  }
}