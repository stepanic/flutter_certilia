// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
// ignore: deprecated_member_use
import 'dart:html' as html;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Alternative authentication method using server polling
/// for cross-origin popup scenarios
class CertiliaWebClientPolling {
  final String serverUrl;
  final http.Client httpClient;
  final bool enableLogging;

  CertiliaWebClientPolling({
    required this.serverUrl,
    http.Client? httpClient,
    this.enableLogging = true,
  }) : httpClient = httpClient ?? http.Client();

  /// Poll server for authentication result
  Future<Map<String, dynamic>?> pollForAuthResult({
    required String sessionId,
    required String state,
    Duration timeout = const Duration(minutes: 5),
    Duration pollInterval = const Duration(seconds: 2),
  }) async {
    _log('Starting server polling for auth result');
    _log('Session ID: $sessionId');
    _log('State: $state');
    
    final endTime = DateTime.now().add(timeout);
    
    while (DateTime.now().isBefore(endTime)) {
      try {
        // Check server for auth result
        final response = await httpClient.get(
          Uri.parse('$serverUrl/api/auth/check-status?session_id=$sessionId&state=$state'),
        );
        
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          _log('Poll response: $data');
          
          if (data['status'] == 'completed') {
            _log('Authentication completed!');
            return data;
          } else if (data['status'] == 'error') {
            _log('Authentication failed: ${data['error']}');
            return null;
          }
          // Otherwise status is 'pending', continue polling
        } else if (response.statusCode != 404) {
          _log('Unexpected status code: ${response.statusCode}');
        }
      } catch (e) {
        _log('Polling error: $e');
      }
      
      // Wait before next poll
      await Future.delayed(pollInterval);
    }
    
    _log('Polling timeout reached');
    return null;
  }

  /// Alternative popup opening with server polling
  Future<String?> openAuthPopupWithPolling(
    String authorizationUrl,
    String sessionId,
    String state,
  ) async {
    final completer = Completer<String?>();
    
    // Calculate popup dimensions
    final width = 500;
    final height = 700;
    final left = (html.window.screen!.width! - width) ~/ 2;
    final top = (html.window.screen!.height! - height) ~/ 2;
    
    _log('Opening popup with server polling');
    _log('Authorization URL: $authorizationUrl');
    
    // Open popup
    final popup = html.window.open(
      authorizationUrl,
      'certilia_auth',
      'width=$width,height=$height,left=$left,top=$top',
    );
    
    // The popup can't be null in dart:html after window.open returns
    // but we check anyway for safety
    
    // Start polling in background
    Timer? popupCheckTimer;
    bool isPolling = true;
    
    // Check if popup is closed
    popupCheckTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (popup.closed ?? false) {
        _log('Popup was closed');
        isPolling = false;
        timer.cancel();
        if (!completer.isCompleted) {
          completer.complete(null);
        }
      }
    });
    
    // Poll server for result
    pollForAuthResult(
      sessionId: sessionId,
      state: state,
    ).then((result) {
      if (isPolling && !completer.isCompleted) {
        popupCheckTimer?.cancel();
        if (result != null && result['code'] != null) {
          completer.complete(result['code']);
        } else {
          completer.complete(null);
        }
        // Try to close popup
        try {
          popup.close();
        } catch (_) {}
      }
    });
    
    return completer.future;
  }

  void _log(String message) {
    if (enableLogging) {
      developer.log(message, name: 'CertiliaWebClientPolling');
      if (kDebugMode) {
        debugPrint('[CertiliaWebClientPolling] $message');
      }
    }
  }
}