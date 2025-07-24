import 'package:flutter/material.dart';
import 'models/certilia_config.dart';
import 'models/certilia_user.dart';

/// Stub implementation that throws on unsupported platforms
class CertiliaPlatformClient {
  CertiliaPlatformClient({
    required CertiliaConfig config,
    String? serverUrl,
  }) {
    throw UnsupportedError('This platform is not supported');
  }

  Future<CertiliaUser> authenticate(BuildContext context) async {
    throw UnsupportedError('Authentication is not supported on this platform');
  }

  bool get isAuthenticated => false;

  Future<CertiliaUser?> getCurrentUser() async => null;

  Future<void> refreshToken() async {
    throw UnsupportedError('Token refresh is not supported on this platform');
  }

  Future<void> logout() async {}

  void dispose() {}
}