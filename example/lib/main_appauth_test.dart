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
      title: 'Certilia AppAuth Test',
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

  @override
  void initState() {
    super.initState();
    _initializeCertilia();
  }

  void _initializeCertilia() {
    // For web, we'll still use the server callback
    // For mobile (AppAuth), we'll use custom URL scheme
    const bool isWeb = identical(0, 0.0); // This is how Flutter detects web
    
    final config = CertiliaConfig(
      clientId: '991dffbb1cdd4d51423e1a5de323f13b15256c63',
      redirectUrl: isWeb 
          ? 'https://uniformly-credible-opossum.ngrok-free.app/api/auth/callback'
          : 'com.example.certilia://oauth',
      scopes: ['openid', 'profile', 'eid', 'email', 'offline_access'],
      enableLogging: true,
    );

    _certilia = CertiliaUniversalClient(
      config: config,
      serverUrl: isWeb ? 'https://uniformly-credible-opossum.ngrok-free.app' : null,
    );
  }

  Future<void> _authenticate() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final user = await _certilia.authenticate(context);
      if (!mounted) return;
      
      setState(() {
        _user = user;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Authentication failed: $e';
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
      if (!mounted) return;
      
      setState(() {
        _user = null;
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Logout failed: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Certilia AppAuth Test'),
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
                  'Welcome, ${_user!.fullName ?? _user!.sub}!',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _logout,
                  icon: const Icon(Icons.logout),
                  label: const Text('Logout'),
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
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _authenticate,
                  icon: const Icon(Icons.login),
                  label: const Text('Sign in with Certilia'),
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
                  child: Text(
                    _error!,
                    style: TextStyle(color: Colors.red.shade700),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _certilia.dispose();
    super.dispose();
  }
}