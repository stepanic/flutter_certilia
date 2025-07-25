import 'package:flutter/material.dart';

import 'certilia_client_stub.dart'
    if (dart.library.io) 'certilia_manual_oauth_client.dart'
    if (dart.library.html) 'certilia_web_client.dart';
import 'models/certilia_config.dart';
import 'models/certilia_user.dart';
import 'models/certilia_extended_info.dart';

/// Universal client that automatically uses the appropriate implementation
/// based on the platform (WebView for mobile, popup for web)
class CertiliaUniversalClient {
  late final dynamic _platformClient;

  /// Creates a new universal client
  CertiliaUniversalClient({
    required CertiliaConfig config,
    String? serverUrl,
  }) {
    _platformClient = CertiliaPlatformClient(
      config: config,
      serverUrl: serverUrl,
    );
  }

  /// Authenticates the user and returns their profile
  Future<CertiliaUser> authenticate(BuildContext context) async {
    return await _platformClient.authenticate(context);
  }

  /// Checks if the user is currently authenticated
  bool get isAuthenticated => _platformClient.isAuthenticated;
  
  /// Checks authentication status including loading from storage
  Future<bool> checkAuthenticationStatus() async {
    return await _platformClient.checkAuthenticationStatus();
  }

  /// Gets the current authenticated user
  Future<CertiliaUser?> getCurrentUser() async {
    return await _platformClient.getCurrentUser();
  }

  /// Refreshes the access token
  Future<void> refreshToken() async {
    await _platformClient.refreshToken();
  }

  /// Logs out the user
  Future<void> logout() async {
    await _platformClient.logout();
  }

  /// Gets extended user information
  Future<CertiliaExtendedInfo?> getExtendedUserInfo() async {
    return await _platformClient.getExtendedUserInfo();
  }
  
  /// Gets the current access token
  String? get currentAccessToken => _platformClient.currentAccessToken;
  
  /// Gets the current refresh token
  String? get currentRefreshToken => _platformClient.currentRefreshToken;
  
  /// Gets the current ID token
  String? get currentIdToken => _platformClient.currentIdToken;
  
  /// Gets the token expiry time
  DateTime? get tokenExpiry => _platformClient.tokenExpiry;

  /// Disposes of resources
  void dispose() {
    _platformClient.dispose();
  }
}