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
      title: 'Certilia Extended Info Example',
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
  CertiliaExtendedInfo? _extendedInfo;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializeCertilia();
  }

  void _initializeCertilia() {
    // Configuration for server-based authentication
    const config = CertiliaConfig(
      clientId: '991dffbb1cdd4d51423e1a5de323f13b15256c63',
      redirectUrl: 'https://uniformly-credible-opossum.ngrok-free.app/api/auth/callback',
      scopes: ['openid', 'profile', 'eid', 'email', 'offline_access'],
      enableLogging: true,
    );

    _certilia = CertiliaUniversalClient(
      config: config,
      serverUrl: 'https://uniformly-credible-opossum.ngrok-free.app',
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
        // Try to get extended info if authenticated
        if (user != null) {
          await _getExtendedInfo();
        }
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
      
      // Get extended info after successful authentication
      await _getExtendedInfo();
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

  Future<void> _getExtendedInfo() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final extendedInfo = await _certilia.getExtendedUserInfo();
      setState(() {
        _extendedInfo = extendedInfo;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to get extended info: $e';
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
        _extendedInfo = null;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Certilia Extended Info Example'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
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
                  
                  // Basic user info
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Basic User Info',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const Divider(),
                          _buildInfoRow('ID', _user!.sub),
                          _buildInfoRow('First Name', _user!.firstName),
                          _buildInfoRow('Last Name', _user!.lastName),
                          _buildInfoRow('OIB', _user!.oib),
                          _buildInfoRow('Email', _user!.email),
                          _buildInfoRow(
                            'Date of Birth',
                            _user!.dateOfBirth?.toString().split(' ')[0],
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Extended info
                  if (_extendedInfo != null) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Extended User Info',
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                IconButton(
                                  icon: const Icon(Icons.refresh),
                                  onPressed: _isLoading ? null : _getExtendedInfo,
                                  tooltip: 'Refresh',
                                ),
                              ],
                            ),
                            const Divider(),
                            Text(
                              'Total fields available: ${_extendedInfo!.availableFields.length}',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 16),
                            
                            // Display all fields in a clean table format
                            Container(
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Theme.of(context).dividerColor,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                children: [
                                  for (int i = 0; i < _extendedInfo!.availableFields.length; i++)
                                    Container(
                                      decoration: BoxDecoration(
                                        color: i % 2 == 0 
                                            ? Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3)
                                            : null,
                                        border: i > 0
                                            ? Border(
                                                top: BorderSide(
                                                  color: Theme.of(context).dividerColor,
                                                  width: 0.5,
                                                ),
                                              )
                                            : null,
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16.0,
                                          vertical: 12.0,
                                        ),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              flex: 2,
                                              child: Text(
                                                _formatFieldName(_extendedInfo!.availableFields[i]),
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 16),
                                            Expanded(
                                              flex: 3,
                                              child: Text(
                                                _extendedInfo!.getField(_extendedInfo!.availableFields[i])?.toString() ?? '-',
                                                style: TextStyle(
                                                  color: Theme.of(context).textTheme.bodyLarge?.color,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            
                            // Token expiry info
                            if (_extendedInfo!.tokenExpiry != null) ...[
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.access_time,
                                      size: 16,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Token expires: ${_formatDateTime(_extendedInfo!.tokenExpiry!)}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Theme.of(context).colorScheme.primary,
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
                  ] else if (!_isLoading) ...[
                    ElevatedButton.icon(
                      onPressed: _getExtendedInfo,
                      icon: const Icon(Icons.info_outline),
                      label: const Text('Get Extended Info'),
                    ),
                  ],
                  
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
      ),
    );
  }

  Widget _buildInfoRow(String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }
  
  String _formatFieldName(String fieldName) {
    // Convert snake_case to Title Case
    return fieldName
        .split('_')
        .map((word) => word.isNotEmpty 
            ? '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}'
            : '')
        .join(' ');
  }
  
  String _formatDateTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    return '${local.day}.${local.month}.${local.year} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _certilia.dispose();
    super.dispose();
  }
}