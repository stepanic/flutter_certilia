import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_certilia_example/main_universal.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Certilia OAuth Flow Integration Tests', () {
    testWidgets('Initial state shows login button', (WidgetTester tester) async {
      // Start the app
      app.main();
      await tester.pumpAndSettle();

      // Verify initial state
      expect(find.text('Not authenticated'), findsOneWidget);
      expect(find.text('Sign in with Certilia'), findsOneWidget);
      expect(find.byKey(const Key('signin_button')), findsOneWidget);
      
      // Verify platform-specific message
      if (kIsWeb) {
        expect(find.text('✓ Authentication opens in popup window'), findsOneWidget);
      } else {
        expect(find.text('✓ Authentication happens in-app'), findsOneWidget);
      }
    });

    testWidgets('Clicking sign in button starts authentication', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Find and tap the sign in button
      final signInButton = find.byKey(const Key('signin_button'));
      expect(signInButton, findsOneWidget);
      
      await tester.tap(signInButton);
      await tester.pump();

      // Verify loading state
      expect(find.byKey(const Key('loading_indicator')), findsOneWidget);
      
      // Button should be disabled during loading
      final button = tester.widget(signInButton) as ElevatedButton;
      expect(button.onPressed, isNull);
    });

    testWidgets('Successful authentication shows user info', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // This test would need to mock the authentication flow
      // In a real scenario, you would:
      // 1. Mock the server responses
      // 2. Mock the WebView/popup behavior
      // 3. Simulate successful authentication
      
      // For demonstration, here's what you would test after successful auth:
      // expect(find.byKey(const Key('welcome_text')), findsOneWidget);
      // expect(find.text('Welcome, Matija Stepanić!'), findsOneWidget);
      // expect(find.byKey(const Key('logout_button')), findsOneWidget);
      // expect(find.byKey(const Key('refresh_button')), findsOneWidget);
    });

    testWidgets('Error handling displays error message', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // This test would simulate an authentication error
      // After error occurs, verify:
      // expect(find.byKey(const Key('error_container')), findsOneWidget);
      // expect(find.textContaining('Authentication failed'), findsOneWidget);
    });

    testWidgets('Logout returns to initial state', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // This test would:
      // 1. Start from authenticated state
      // 2. Tap logout button
      // 3. Verify return to initial state
      
      // After logout:
      // expect(find.text('Not authenticated'), findsOneWidget);
      // expect(find.byKey(const Key('signin_button')), findsOneWidget);
    });

    testWidgets('Token refresh updates user info', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // This test would:
      // 1. Start from authenticated state
      // 2. Tap refresh button
      // 3. Verify loading state
      // 4. Verify updated user info
    });
  });
}