import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_certilia/flutter_certilia.dart';

// Test widget that simulates the authentication flow
class TestAuthWidget extends StatefulWidget {
  const TestAuthWidget({super.key});

  @override
  State<TestAuthWidget> createState() => _TestAuthWidgetState();
}

class _TestAuthWidgetState extends State<TestAuthWidget> {
  CertiliaUser? _user;
  bool _isLoading = false;
  String? _error;

  // Mock user for testing
  final _mockUser = CertiliaUser(
    sub: '12345678901',
    firstName: 'Test',
    lastName: 'User',
    email: 'test@example.com',
    oib: '69435151530',
    dateOfBirth: DateTime(1990, 1, 1),
    raw: const {},
  );

  Future<void> _mockAuthenticate() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 100));

    setState(() {
      _user = _mockUser;
      _isLoading = false;
    });
  }

  Future<void> _mockLogout() async {
    setState(() {
      _isLoading = true;
    });

    await Future.delayed(const Duration(milliseconds: 100));

    setState(() {
      _user = null;
      _isLoading = false;
    });
  }

  void _mockError() {
    setState(() {
      _error = 'Mock authentication error';
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_user != null) ...[
                Text('Welcome, ${_user!.fullName}!', key: const Key('welcome_text')),
                const SizedBox(height: 16),
                Text('OIB: ${_user!.oib}', key: const Key('oib_text')),
                const SizedBox(height: 16),
                ElevatedButton(
                  key: const Key('logout_button'),
                  onPressed: _isLoading ? null : _mockLogout,
                  child: const Text('Logout'),
                ),
              ] else ...[
                const Text('Not authenticated', key: Key('not_authenticated_text')),
                const SizedBox(height: 16),
                ElevatedButton(
                  key: const Key('signin_button'),
                  onPressed: _isLoading ? null : _mockAuthenticate,
                  child: const Text('Sign in'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  key: const Key('error_button'),
                  onPressed: _mockError,
                  child: const Text('Trigger Error'),
                ),
              ],
              if (_isLoading)
                const CircularProgressIndicator(key: Key('loading_indicator')),
              if (_error != null)
                Text(
                  _error!,
                  key: const Key('error_text'),
                  style: const TextStyle(color: Colors.red),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

void main() {
  group('Authentication Widget Tests', () {
    testWidgets('Initial state shows sign in button', (WidgetTester tester) async {
      await tester.pumpWidget(const TestAuthWidget());

      expect(find.byKey(const Key('not_authenticated_text')), findsOneWidget);
      expect(find.byKey(const Key('signin_button')), findsOneWidget);
      expect(find.byKey(const Key('welcome_text')), findsNothing);
    });

    testWidgets('Sign in flow shows loading and then user info', (WidgetTester tester) async {
      await tester.pumpWidget(const TestAuthWidget());

      // Tap sign in button
      await tester.tap(find.byKey(const Key('signin_button')));
      await tester.pump();

      // Verify loading state
      expect(find.byKey(const Key('loading_indicator')), findsOneWidget);
      
      // Wait for async operation
      await tester.pumpAndSettle();

      // Verify authenticated state
      expect(find.byKey(const Key('welcome_text')), findsOneWidget);
      expect(find.text('Welcome, Test User!'), findsOneWidget);
      expect(find.byKey(const Key('oib_text')), findsOneWidget);
      expect(find.text('OIB: 69435151530'), findsOneWidget);
      expect(find.byKey(const Key('logout_button')), findsOneWidget);
      expect(find.byKey(const Key('signin_button')), findsNothing);
    });

    testWidgets('Logout returns to initial state', (WidgetTester tester) async {
      await tester.pumpWidget(const TestAuthWidget());

      // Sign in first
      await tester.tap(find.byKey(const Key('signin_button')));
      await tester.pumpAndSettle();

      // Now logout
      await tester.tap(find.byKey(const Key('logout_button')));
      await tester.pump();

      // Verify loading
      expect(find.byKey(const Key('loading_indicator')), findsOneWidget);

      await tester.pumpAndSettle();

      // Verify back to initial state
      expect(find.byKey(const Key('not_authenticated_text')), findsOneWidget);
      expect(find.byKey(const Key('signin_button')), findsOneWidget);
      expect(find.byKey(const Key('welcome_text')), findsNothing);
    });

    testWidgets('Error handling shows error message', (WidgetTester tester) async {
      await tester.pumpWidget(const TestAuthWidget());

      // Trigger error
      await tester.tap(find.byKey(const Key('error_button')));
      await tester.pump();

      // Verify error message
      expect(find.byKey(const Key('error_text')), findsOneWidget);
      expect(find.text('Mock authentication error'), findsOneWidget);
    });

    testWidgets('Button is disabled during loading', (WidgetTester tester) async {
      await tester.pumpWidget(const TestAuthWidget());

      // Start sign in
      await tester.tap(find.byKey(const Key('signin_button')));
      await tester.pump();

      // Try to tap button again (should be disabled)
      final button = tester.widget<ElevatedButton>(find.byKey(const Key('signin_button')));
      expect(button.onPressed, isNull);
    });
  });

  // OIB validation tests removed as OIBValidator is not exported

  group('CertiliaUser Model Tests', () {
    test('User creation with all fields', () {
      final user = CertiliaUser(
        sub: '12345678901',
        firstName: 'John',
        lastName: 'Doe',
        email: 'john@example.com',
        oib: '69435151530',
        dateOfBirth: DateTime(1990, 1, 1),
        raw: const {},
      );

      expect(user.sub, equals('12345678901'));
      expect(user.firstName, equals('John'));
      expect(user.lastName, equals('Doe'));
      expect(user.fullName, equals('John Doe'));
      expect(user.email, equals('john@example.com'));
      expect(user.oib, equals('69435151530'));
      expect(user.dateOfBirth?.year, equals(1990));
    });

    test('User JSON serialization', () {
      final user = CertiliaUser(
        sub: '12345678901',
        firstName: 'John',
        lastName: 'Doe',
        email: 'john@example.com',
        raw: const {},
      );

      final json = user.toJson();
      expect(json['sub'], equals('12345678901'));
      expect(json['firstName'], equals('John'));
      expect(json['lastName'], equals('Doe'));
      expect(json['email'], equals('john@example.com'));

      // Deserialize back
      final user2 = CertiliaUser.fromJson(json);
      expect(user2.sub, equals(user.sub));
      expect(user2.firstName, equals(user.firstName));
      expect(user2.lastName, equals(user.lastName));
      expect(user2.email, equals(user.email));
    });
  });
}