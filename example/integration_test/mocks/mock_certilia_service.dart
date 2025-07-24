import 'dart:async';
import 'package:flutter_certilia/flutter_certilia.dart';

/// Mock service for testing OAuth flow
class MockCertiliaService {
  static bool shouldSucceed = true;
  static Duration authDelay = const Duration(seconds: 1);
  
  /// Mock user data
  static final mockUser = CertiliaUser(
    sub: '59386932137',
    firstName: 'Test',
    lastName: 'User',
    fullName: 'Test User',
    email: 'test@example.com',
    oib: '69435151530',
    dateOfBirth: DateTime(1990, 12, 19),
  );

  /// Simulate authentication flow
  static Future<CertiliaUser> authenticate() async {
    await Future.delayed(authDelay);
    
    if (!shouldSucceed) {
      throw const CertiliaAuthenticationException(
        message: 'Mock authentication failed',
      );
    }
    
    return mockUser;
  }

  /// Simulate token refresh
  static Future<void> refreshToken() async {
    await Future.delayed(const Duration(milliseconds: 500));
    
    if (!shouldSucceed) {
      throw const CertiliaAuthenticationException(
        message: 'Mock token refresh failed',
      );
    }
  }

  /// Reset mock state
  static void reset() {
    shouldSucceed = true;
    authDelay = const Duration(seconds: 1);
  }
}