/// Authentication state enum
enum AuthState {
  /// Initial state, checking stored authentication
  initial,

  /// Checking stored credentials
  checking,

  /// Currently authenticating
  authenticating,

  /// User is authenticated
  authenticated,

  /// User is not authenticated
  unauthenticated,
}