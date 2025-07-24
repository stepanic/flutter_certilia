import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Certilia Server Example',
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
  // ngrok server URL
  static const String serverUrl = 'https://uniformly-credible-opossum.ngrok-free.app';
  
  bool _isLoading = false;
  String? _error;
  Map<String, dynamic>? _authData;
  Map<String, dynamic>? _userData;
  String? _accessToken;

  Future<void> _startAuthentication() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Step 1: Initialize OAuth flow
      final initResponse = await http.get(
        Uri.parse('$serverUrl/api/auth/initialize?redirect_uri=$serverUrl/api/auth/callback'),
      );

      if (initResponse.statusCode != 200) {
        throw Exception('Failed to initialize auth: ${initResponse.body}');
      }

      final authData = jsonDecode(initResponse.body);
      setState(() {
        _authData = authData;
      });

      // Step 2: Open authorization URL in browser
      final authUrl = authData['authorization_url'];
      if (await canLaunchUrl(Uri.parse(authUrl))) {
        await launchUrl(
          Uri.parse(authUrl),
          mode: LaunchMode.externalApplication,
        );
      } else {
        throw Exception('Could not launch $authUrl');
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _exchangeCode(String code) async {
    if (_authData == null) {
      setState(() {
        _error = 'No auth session found. Please start authentication first.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Exchange code for tokens
      final exchangeResponse = await http.post(
        Uri.parse('$serverUrl/api/auth/exchange'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'code': code,
          'state': _authData!['state'],
          'session_id': _authData!['session_id'],
        }),
      );

      if (exchangeResponse.statusCode != 200) {
        throw Exception('Failed to exchange code: ${exchangeResponse.body}');
      }

      final tokenData = jsonDecode(exchangeResponse.body);
      setState(() {
        _accessToken = tokenData['accessToken'];
        _userData = tokenData['user'];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _getUserInfo() async {
    if (_accessToken == null) {
      setState(() {
        _error = 'No access token available';
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final userResponse = await http.get(
        Uri.parse('$serverUrl/api/auth/user'),
        headers: {
          'Authorization': 'Bearer $_accessToken',
        },
      );

      if (userResponse.statusCode != 200) {
        throw Exception('Failed to get user info: ${userResponse.body}');
      }

      final userData = jsonDecode(userResponse.body);
      setState(() {
        _userData = userData['user'];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _logout() async {
    setState(() {
      _authData = null;
      _userData = null;
      _accessToken = null;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Certilia Server Example'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_userData != null) ...[
                  const Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size: 64,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Welcome, ${_userData!['firstName'] ?? 'User'}!',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 32),
                  _buildUserInfo('ID', _userData!['sub']),
                  _buildUserInfo('First Name', _userData!['firstName']),
                  _buildUserInfo('Last Name', _userData!['lastName']),
                  _buildUserInfo('OIB', _userData!['oib']),
                  _buildUserInfo('Email', _userData!['email']),
                  _buildUserInfo('Date of Birth', _userData!['dateOfBirth']),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _getUserInfo,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Refresh'),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton.icon(
                        onPressed: _logout,
                        icon: const Icon(Icons.logout),
                        label: const Text('Logout'),
                      ),
                    ],
                  ),
                ] else if (_authData != null) ...[
                  const Icon(
                    Icons.key,
                    size: 64,
                    color: Colors.orange,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Authentication Started',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Complete authentication in your browser, then paste the code below:',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Session ID: ${_authData!['session_id']}'),
                        Text('State: ${_authData!['state']}'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: 300,
                    child: TextField(
                      decoration: const InputDecoration(
                        labelText: 'Authorization Code',
                        hintText: 'Paste code from callback URL',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: _exchangeCode,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: _startAuthentication,
                    child: const Text('Restart Authentication'),
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
                    'Using server: $serverUrl',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _startAuthentication,
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

  Widget _buildUserInfo(String label, dynamic value) {
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
          Text(value.toString()),
        ],
      ),
    );
  }
}