# flutter_certilia

[![pub package](https://img.shields.io/pub/v/flutter_certilia.svg)](https://pub.dev/packages/flutter_certilia)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Flutter SDK for Certilia Identity API integration. Supports OAuth 2.0 authentication with Croatian eID (eOsobna) through NIAS system.

Flutter SDK za integraciju s Certilia Identity API-jem. Podržava OAuth 2.0 autentifikaciju s hrvatskom elektroničkom osobnom iskaznicom (eOsobna) kroz NIAS sustav.

## Features

- 🔐 OAuth 2.0 authentication with PKCE support
- 🆔 Croatian eID (eOsobna) integration through NIAS
- 📱 Support for iOS, Android, and Web platforms
- 🔄 Automatic token refresh
- 💾 Secure token storage
- 🛡️ Null safety
- 📝 Comprehensive logging

## Installation

Add `flutter_certilia` to your `pubspec.yaml`:

```yaml
dependencies:
  flutter_certilia: ^0.1.0
```

Then run:

```bash
flutter pub get
```

## Usage

### Recommended: Client-Server Architecture

For production applications, we recommend using a backend proxy server:

```dart
import 'package:flutter_certilia/flutter_certilia.dart';

// Simple configuration - Flutter only knows about YOUR server
final certilia = await CertiliaSDKSimple.initialize(
  clientId: 'your_client_id',
  serverUrl: 'https://your-backend-server.com',
  scopes: ['openid', 'profile', 'eid'],
);

// Authenticate
final user = await certilia.authenticate(context);
```

Benefits:
- ✅ API credentials stay secure on your server
- ✅ Simplified Flutter client configuration
- ✅ Centralized OAuth flow management
- ✅ Better security and control

### Alternative: Direct Integration

```dart
// Direct configuration (not recommended for production)
final config = CertiliaConfig(
  clientId: 'your_client_id',
  redirectUrl: 'com.example.app://callback',
  baseUrl: 'https://idp.test.certilia.com',
  // ... other API endpoints
);

final certilia = CertiliaClient(config: config);

// Authenticate user
try {
  final user = await certilia.authenticate();
  print('Welcome ${user.fullName}!');
  print('OIB: ${user.oib}');
} catch (e) {
  print('Authentication failed: $e');
}

// Check if authenticated
if (certilia.isAuthenticated) {
  // Get current user
  final user = await certilia.getCurrentUser();
}

// Logout
await certilia.logout();
```

### Advanced Configuration

```dart
final config = CertiliaConfig(
  clientId: 'your_client_id',
  redirectUrl: 'com.example.app://callback',
  scopes: ['openid', 'profile', 'eid'],
  preferEphemeralSession: true,  // iOS only
  enableLogging: true,  // Enable debug logs
  customUserAgent: 'MyApp/1.0',  // Custom user agent
);
```

## Platform Configuration

### iOS

Add the following to your `ios/Runner/Info.plist`:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>com.example.app</string>
        </array>
    </dict>
</array>
```

### Android

1. Add the following to your `android/app/build.gradle`:

```gradle
android {
    defaultConfig {
        manifestPlaceholders += [
            'appAuthRedirectScheme': 'com.example.app'
        ]
    }
}
```

2. Ensure minimum SDK version is 16 or higher:

```gradle
android {
    defaultConfig {
        minSdkVersion 16
    }
}
```

### Web

No additional configuration required for web platform.

## API Reference

### CertiliaClient

Main client class for authentication operations.

#### Methods

- `authenticate()` - Performs OAuth authentication flow
- `getCurrentUser()` - Gets the currently authenticated user
- `refreshToken()` - Refreshes the access token
- `logout()` - Clears local authentication state
- `endSession()` - Ends the OAuth session at the server

### CertiliaConfig

Configuration object for the client.

#### Properties

- `clientId` - OAuth client ID (required)
- `redirectUrl` - OAuth redirect URL (required)
- `scopes` - List of OAuth scopes (default: `['openid', 'profile', 'eid']`)
- `preferEphemeralSession` - Use ephemeral session on iOS (default: `true`)
- `enableLogging` - Enable debug logging (default: `false`)

### CertiliaUser

User object containing identity information.

#### Properties

- `sub` - Unique user identifier
- `firstName` - User's first name
- `lastName` - User's last name
- `fullName` - Combined first and last name
- `oib` - Croatian tax number (OIB)
- `dateOfBirth` - User's date of birth
- `email` - User's email address

## Error Handling

The SDK provides specific exception types for different error scenarios:

```dart
try {
  await certilia.authenticate();
} on CertiliaAuthenticationException catch (e) {
  // Handle authentication errors
  print('Auth failed: ${e.message}');
} on CertiliaNetworkException catch (e) {
  // Handle network errors
  print('Network error: ${e.message} (HTTP ${e.statusCode})');
} on CertiliaConfigurationException catch (e) {
  // Handle configuration errors
  print('Config error: ${e.message}');
} catch (e) {
  // Handle other errors
}
```

## Troubleshooting

### Common Issues

1. **Authentication cancelled**
   - Ensure redirect URL is properly configured
   - Check that the app URL scheme matches the redirect URL

2. **Network errors**
   - Verify internet connectivity
   - Check that Certilia servers are accessible

3. **Token refresh fails**
   - Ensure refresh token is available
   - Check token expiration

### Debug Mode

Enable logging to troubleshoot issues:

```dart
final config = CertiliaConfig(
  clientId: 'your_client_id',
  redirectUrl: 'com.example.app://callback',
  enableLogging: true,
);
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

For issues and feature requests, please use the [GitHub issue tracker](https://github.com/stepanic/flutter_certilia/issues).