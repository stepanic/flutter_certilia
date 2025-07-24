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
      title: 'Certilia Example',
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
  late final CertiliaClient _certilia;
  CertiliaUser? _user;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializeCertilia();
  }

  void _initializeCertilia() {
    // Replace with your actual client ID and redirect URL
    const config = CertiliaConfig(
      clientId: 'your_client_id_here',
      redirectUrl: 'com.example.certilia://callback',
      scopes: ['openid', 'profile', 'eid'],
      enableLogging: true,
    );

    _certilia = CertiliaClient(config: config);
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
      final user = await _certilia.authenticate();
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

  Future<void> _endSession() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _certilia.endSession();
      setState(() {
        _user = null;
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _error = 'End session failed: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Certilia Example'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
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
                ),
                const SizedBox(height: 32),
                _buildUserInfo('ID', _user!.sub),
                _buildUserInfo('First Name', _user!.firstName),
                _buildUserInfo('Last Name', _user!.lastName),
                _buildUserInfo('OIB', _user!.oib),
                _buildUserInfo('Email', _user!.email),
                _buildUserInfo(
                  'Date of Birth',
                  _user!.dateOfBirth?.toString().split(' ')[0],
                ),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _logout,
                      icon: const Icon(Icons.logout),
                      label: const Text('Logout'),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _endSession,
                      icon: const Icon(Icons.exit_to_app),
                      label: const Text('End Session'),
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
                const SizedBox(height: 32),
                ElevatedButton.icon(
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
                const CircularProgressIndicator(),
              ],
              if (_error != null) ...[
                const SizedBox(height: 32),
                Container(
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
            ],
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
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(value),
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