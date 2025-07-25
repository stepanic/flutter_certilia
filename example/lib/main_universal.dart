import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_certilia/flutter_certilia.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Certilia Universal Example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final CertiliaUniversalClient _certilia;
  CertiliaUser? _user;
  bool _isLoading = false;
  String? _error;

  // Server configuration
  static const String serverUrl = 'https://uniformly-credible-opossum.ngrok-free.app';
  static const String clientId = '991dffbb1cdd4d51423e1a5de323f13b15256c63';

  @override
  void initState() {
    super.initState();
    _initializeCertilia();
  }

  void _initializeCertilia() {
    // Configuration for universal client
    const config = CertiliaConfig(
      clientId: clientId,
      redirectUrl: '$serverUrl/api/auth/callback',
      scopes: ['openid', 'profile', 'eid', 'email', 'offline_access'],
      enableLogging: true,
    );

    _certilia = CertiliaUniversalClient(
      config: config,
      serverUrl: serverUrl,
    );
    
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    if (_certilia.isAuthenticated) {
      try {
        final user = await _certilia.getCurrentUser();
        setState(() {
          _user = user;
        });
      } catch (e) {
        debugPrint('Failed to get current user: $e');
      }
    }
  }

  Future<void> _authenticate() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final user = await _certilia.authenticate(context);
      setState(() {
        _user = user;
        _isLoading = false;
      });
    } on CertiliaAuthenticationException catch (e) {
      setState(() {
        _error = 'Authentication failed: ${e.message}';
        _isLoading = false;
      });
    } on CertiliaNetworkException catch (e) {
      setState(() {
        _error = 'Network error: ${e.message}';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Unexpected error: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _logout() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _certilia.logout();
      setState(() {
        _user = null;
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _error = 'Logout failed: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshToken() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _certilia.refreshToken();
      // Reload user info
      final user = await _certilia.getCurrentUser();
      setState(() {
        _user = user;
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _error = 'Token refresh failed: $e';
        _isLoading = false;
      });
    }
  }

  String get _platformInfo {
    if (kIsWeb) {
      return 'Web (popup authentication)';
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      return 'iOS (in-app WebView)';
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      return 'Android (in-app WebView)';
    } else {
      return defaultTargetPlatform.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Certilia Universal Example'),
        actions: [
          Chip(
            label: Text(
              _platformInfo,
              style: const TextStyle(fontSize: 12),
            ),
            backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_user != null) ...[
                  const Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size: 64,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Welcome, ${_user!.fullName ?? 'User'}!',
                    style: Theme.of(context).textTheme.headlineSmall,
                    key: const Key('welcome_text'),
                  ),
                  const SizedBox(height: 32),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _buildUserInfo('ID', _user!.sub),
                          _buildUserInfo('First Name', _user!.firstName),
                          _buildUserInfo('Last Name', _user!.lastName),
                          _buildUserInfo('OIB', _user!.oib),
                          _buildUserInfo('Email', _user!.email),
                          _buildUserInfo(
                            'Date of Birth',
                            _user!.dateOfBirth?.toString().split(' ')[0],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Wrap(
                    spacing: 16,
                    children: [
                      ElevatedButton.icon(
                        key: const Key('refresh_button'),
                        onPressed: _isLoading ? null : _refreshToken,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Refresh Token'),
                      ),
                      ElevatedButton.icon(
                        key: const Key('logout_button'),
                        onPressed: _isLoading ? null : _logout,
                        icon: const Icon(Icons.logout),
                        label: const Text('Logout'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  const Icon(
                    Icons.lock_outline,
                    size: 64,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Not authenticated',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Sign in with your Croatian eID',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.info_outline, color: Colors.blue, size: 20),
                        const SizedBox(height: 4),
                        Text(
                          kIsWeb
                              ? 'Authentication opens in popup window'
                              : 'Authentication happens in-app',
                          style: const TextStyle(
                            color: Colors.blue,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    key: const Key('signin_button'),
                    onPressed: _isLoading ? null : _authenticate,
                    icon: const Icon(Icons.login),
                    label: const Text('Sign in with Certilia'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                    ),
                  ),
                ],
                if (_isLoading) ...[
                  const SizedBox(height: 32),
                  const CircularProgressIndicator(
                    key: Key('loading_indicator'),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 32),
                  Container(
                    key: const Key('error_container'),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.red.shade700),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _error!,
                            style: TextStyle(color: Colors.red.shade700),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const Spacer(),
                Text(
                  'Platform: $_platformInfo',
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Server: $serverUrl',
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUserInfo(String label, String? value) {
    if (value == null) return const SizedBox.shrink();
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontFamily: 'monospace'),
              key: Key('user_info_$label'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _certilia.dispose();
    super.dispose();
  }
}