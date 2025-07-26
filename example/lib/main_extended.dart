import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  DateTime? _tokenExpiryTime;
  bool _isEnglish = false; // Default to Croatian

  @override
  void initState() {
    super.initState();
    _initializeCertilia();
  }

  void _initializeCertilia() {
    // Configuration for authentication
    // Using HTTPS redirect URL with polling approach
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
    // Give time for async token loading to complete
    Future.delayed(const Duration(milliseconds: 100), () {
      _checkAuthStatus();
    });
  }

  Future<void> _checkAuthStatus() async {
    // Check authentication status (loads from storage if needed)
    final isAuth = await _certilia.checkAuthenticationStatus();
    
    if (isAuth) {
      try {
        final user = await _certilia.getCurrentUser();
        if (!mounted) return;
        
        setState(() {
          _user = user;
        });
        // Try to get extended info if authenticated
        if (user != null) {
          await _getExtendedInfo();
        }
      } catch (e) {
        debugPrint('Failed to get current user: $e');
        // If we failed to get user, check if we're still authenticated
        if (!_certilia.isAuthenticated && mounted) {
          setState(() {
            _user = null;
            _extendedInfo = null;
            _tokenExpiryTime = null;
            _error = _isEnglish 
                ? 'Session expired. Please sign in again.'
                : 'Sesija je istekla. Molimo prijavite se ponovno.';
          });
        }
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
      if (!mounted) return;
      
      setState(() {
        _user = user;
        _isLoading = false;
      });
      
      // Get extended info after successful authentication
      await _getExtendedInfo();
    } on CertiliaAuthenticationException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Authentication failed: ${e.message}';
        _isLoading = false;
      });
    } on CertiliaNetworkException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Network error: ${e.message}';
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Unexpected error: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _getExtendedInfo() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      final extendedInfo = await _certilia.getExtendedUserInfo();
      if (!mounted) return;
      
      // Check if we got null because of logout
      if (extendedInfo == null && !_certilia.isAuthenticated) {
        // Token was expired and user was logged out
        setState(() {
          _user = null;
          _extendedInfo = null;
          _tokenExpiryTime = null;
          _isLoading = false;
          _error = _isEnglish 
              ? 'Session expired. Please sign in again.'
              : 'Sesija je istekla. Molimo prijavite se ponovno.';
        });
        return;
      }
      
      setState(() {
        _extendedInfo = extendedInfo;
        _tokenExpiryTime = extendedInfo?.tokenExpiry;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to get extended info: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshToken() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await _certilia.refreshToken();
      setState(() {
        _isLoading = false;
      });
      
      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEnglish 
                ? 'Token refreshed successfully'
                : 'Token uspješno osvježen'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
      
      // Refresh user data with new token
      await _checkAuthStatus();
      await _getExtendedInfo();
    } catch (e) {
      setState(() {
        _error = 'Token refresh failed: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _logout() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      await _certilia.logout();
      if (!mounted) return;
      
      setState(() {
        _user = null;
        _extendedInfo = null;
        _isLoading = false;
        _error = null;
        _tokenExpiryTime = null;
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
        title: const Text('Certilia Extended Info Example'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Language toggle
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: !_isEnglish ? null : () => setState(() => _isEnglish = false),
                      style: TextButton.styleFrom(
                        backgroundColor: !_isEnglish 
                            ? Theme.of(context).colorScheme.primary 
                            : Colors.transparent,
                        foregroundColor: !_isEnglish 
                            ? Theme.of(context).colorScheme.onPrimary 
                            : Theme.of(context).colorScheme.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      ),
                      child: const Text('HR'),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: _isEnglish ? null : () => setState(() => _isEnglish = true),
                      style: TextButton.styleFrom(
                        backgroundColor: _isEnglish 
                            ? Theme.of(context).colorScheme.primary 
                            : Colors.transparent,
                        foregroundColor: _isEnglish 
                            ? Theme.of(context).colorScheme.onPrimary 
                            : Theme.of(context).colorScheme.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      ),
                      child: const Text('EN'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                if (_user != null) ...[
                  const Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size: 64,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _isEnglish 
                        ? 'Welcome, ${_user!.fullName ?? 'User'}!'
                        : 'Dobrodošli, ${_user!.fullName ?? 'Korisnik'}!',
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
                            _isEnglish ? 'Basic User Info' : 'Osnovni podaci',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const Divider(),
                          _buildInfoRow('ID', _user!.sub),
                          _buildInfoRow(_isEnglish ? 'First Name' : 'Ime', _user!.firstName),
                          _buildInfoRow(_isEnglish ? 'Last Name' : 'Prezime', _user!.lastName),
                          _buildInfoRow('OIB', _user!.oib),
                          _buildInfoRow(_isEnglish ? 'Email' : 'E-pošta', _user!.email),
                          _buildInfoRow(
                            _isEnglish ? 'Date of Birth' : 'Datum rođenja',
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
                                  _isEnglish ? 'Extended User Info' : 'Prošireni podaci',
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                IconButton(
                                  icon: const Icon(Icons.refresh),
                                  onPressed: _isLoading ? null : _getExtendedInfo,
                                  tooltip: _isEnglish ? 'Refresh' : 'Osvježi',
                                ),
                              ],
                            ),
                            const Divider(),
                            Text(
                              _isEnglish 
                                  ? 'Total fields available: ${_extendedInfo!.availableFields.length}'
                                  : 'Ukupno dostupnih polja: ${_extendedInfo!.availableFields.length}',
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
                                      _isEnglish 
                                          ? 'Token expires: ${_formatDateTime(_extendedInfo!.tokenExpiry!)}'
                                          : 'Token ističe: ${_formatDateTime(_extendedInfo!.tokenExpiry!)}',
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
                      label: Text(_isEnglish ? 'Get Extended Info' : 'Dohvati proširene podatke'),
                    ),
                  ],
                  
                  const SizedBox(height: 16),
                  
                  // Token display section
                  Card(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isEnglish ? 'Authentication Tokens' : 'Autentifikacijski tokeni',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 16),
                          // Access Token
                          _buildTokenRow(
                            context,
                            'Access Token',
                            _certilia.currentAccessToken,
                            Icons.key,
                          ),
                          const SizedBox(height: 12),
                          // Refresh Token
                          _buildTokenRow(
                            context,
                            'Refresh Token',
                            _certilia.currentRefreshToken,
                            Icons.refresh,
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Token status info
                  if (_tokenExpiryTime != null) ...[
                    Card(
                      color: _isTokenExpiringSoon() 
                          ? Theme.of(context).colorScheme.errorContainer
                          : Theme.of(context).colorScheme.secondaryContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.access_time,
                              size: 20,
                              color: _isTokenExpiringSoon()
                                  ? Theme.of(context).colorScheme.error
                                  : Theme.of(context).colorScheme.secondary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _isEnglish 
                                  ? 'Token expires in: ${_getTimeUntilExpiry()}'
                                  : 'Token ističe za: ${_getTimeUntilExpiry()}',
                              style: TextStyle(
                                color: _isTokenExpiringSoon()
                                    ? Theme.of(context).colorScheme.error
                                    : Theme.of(context).colorScheme.onSecondaryContainer,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _isLoading ? null : _refreshToken,
                        icon: const Icon(Icons.refresh),
                        label: Text(_isEnglish ? 'Refresh Token' : 'Osvježi token'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.secondary,
                          foregroundColor: Theme.of(context).colorScheme.onSecondary,
                        ),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton.icon(
                        onPressed: _isLoading ? null : _logout,
                        icon: const Icon(Icons.logout),
                        label: Text(_isEnglish ? 'Logout' : 'Odjava'),
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
                    _isEnglish ? 'Not authenticated' : 'Niste prijavljeni',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isEnglish 
                        ? 'Sign in with your Croatian eID'
                        : 'Prijavite se s hrvatskom osobnom iskaznicom',
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 32),
                  InkWell(
                    onTap: _isLoading ? null : _authenticate,
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(
                      _isEnglish 
                          ? 'assets/images/sign_in_with_certilia.png'
                          : 'assets/images/prijava_sa_certilia.png',
                      width: 256,
                      fit: BoxFit.contain,
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
  
  bool _isTokenExpiringSoon() {
    if (_tokenExpiryTime == null) return false;
    final timeUntilExpiry = _tokenExpiryTime!.difference(DateTime.now());
    return timeUntilExpiry.inMinutes < 5; // Consider expiring soon if less than 5 minutes
  }
  
  String _getTimeUntilExpiry() {
    if (_tokenExpiryTime == null) return _isEnglish ? 'Unknown' : 'Nepoznato';
    
    final timeUntilExpiry = _tokenExpiryTime!.difference(DateTime.now());
    
    if (timeUntilExpiry.isNegative) {
      return _isEnglish ? 'Expired' : 'Istekao';
    }
    
    if (timeUntilExpiry.inDays > 0) {
      return _isEnglish 
          ? '${timeUntilExpiry.inDays} days'
          : '${timeUntilExpiry.inDays} ${timeUntilExpiry.inDays == 1 ? 'dan' : 'dana'}';
    } else if (timeUntilExpiry.inHours > 0) {
      return _isEnglish 
          ? '${timeUntilExpiry.inHours} hours'
          : '${timeUntilExpiry.inHours} ${timeUntilExpiry.inHours == 1 ? 'sat' : timeUntilExpiry.inHours < 5 ? 'sata' : 'sati'}';
    } else if (timeUntilExpiry.inMinutes > 0) {
      return _isEnglish 
          ? '${timeUntilExpiry.inMinutes} minutes'
          : '${timeUntilExpiry.inMinutes} ${timeUntilExpiry.inMinutes == 1 ? 'minuta' : timeUntilExpiry.inMinutes < 5 ? 'minute' : 'minuta'}';
    } else {
      return _isEnglish 
          ? '${timeUntilExpiry.inSeconds} seconds'
          : '${timeUntilExpiry.inSeconds} ${timeUntilExpiry.inSeconds == 1 ? 'sekunda' : timeUntilExpiry.inSeconds < 5 ? 'sekunde' : 'sekundi'}';
    }
  }
  
  Widget _buildTokenRow(
    BuildContext context,
    String label,
    String? token,
    IconData icon,
  ) {
    if (token == null) return const SizedBox.shrink();
    
    final truncatedToken = token.length > 50 
        ? '${token.substring(0, 20)}...${token.substring(token.length - 20)}' 
        : token;
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).dividerColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.copy, size: 16),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: token));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(_isEnglish 
                          ? '$label copied to clipboard'
                          : '$label kopiran u međuspremnik'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                tooltip: _isEnglish ? 'Copy to clipboard' : 'Kopiraj u međuspremnik',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                iconSize: 16,
              ),
            ],
          ),
          const SizedBox(height: 8),
          SelectableText(
            truncatedToken,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              color: Theme.of(context).textTheme.bodySmall?.color,
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