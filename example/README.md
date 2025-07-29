# flutter_certilia Example

This example demonstrates how to use the flutter_certilia SDK with direct parameter configuration (no .env files required).

## Features

- OAuth 2.0 authentication with Croatian eID
- Direct SDK initialization with all parameters
- Bilingual support (Croatian/English)
- Extended user information retrieval
- Token management and refresh
- Session persistence across app restarts
- Token expiry tracking
- Secure token display with copy functionality

## Setup

### Prerequisites

1. **Server Setup**: You need a running authentication server. The example uses:
   ```
   https://uniformly-credible-opossum.ngrok-free.app
   ```

2. **Client Configuration**: The example includes a test client ID:
   ```
   991dffbb1cdd4d51423e1a5de323f13b15256c63
   ```

## Running the Example

```bash
# For Android/iOS
flutter run

# For Web
flutter run -d chrome

# With specific device
flutter run -d <device_id>
```

## SDK Configuration

The example demonstrates how to initialize CertiliaSDK with all parameters:

```dart
final config = CertiliaConfig(
  // Core OAuth parameters
  clientId: '991dffbb1cdd4d51423e1a5de323f13b15256c63',
  redirectUrl: 'https://uniformly-credible-opossum.ngrok-free.app/api/auth/callback',
  
  // OAuth endpoints
  baseUrl: 'https://idp.test.certilia.com',
  authorizationEndpoint: 'https://idp.test.certilia.com/oauth2/authorize',
  tokenEndpoint: 'https://idp.test.certilia.com/oauth2/token',
  userInfoEndpoint: 'https://idp.test.certilia.com/oauth2/userinfo',
  
  // Optional parameters
  serverUrl: 'https://uniformly-credible-opossum.ngrok-free.app',
  scopes: ['openid', 'profile', 'eid', 'email', 'offline_access'],
  enableLogging: true,
  preferEphemeralSession: true,
  sessionTimeout: 3600000, // 1 hour
  refreshTokenTimeout: 2592000000, // 30 days
);

final client = await CertiliaSDK.initialize(config: config);
```

## Platform Behavior

The SDK automatically selects the appropriate authentication method:

- **Web**: Opens authentication in a popup window
- **Mobile**: Uses AppAuth with fallback to WebView
- **Desktop**: Uses WebView implementation

## Features Demonstrated

1. **Authentication Flow**
   - Sign in with Croatian eID
   - Automatic session restoration

2. **User Information**
   - Basic user info (name, email, OIB, date of birth)
   - Extended user information with all available fields

3. **Token Management**
   - Display access and refresh tokens
   - Copy tokens to clipboard
   - Refresh token functionality
   - Token expiry countdown

4. **Error Handling**
   - Network errors
   - Authentication failures
   - Session expiration

## Troubleshooting

### Common Issues

1. **Server Connection Failed**
   - Ensure the server URL is accessible
   - Check network connectivity
   - Verify firewall settings

2. **Authentication Fails**
   - Verify client ID is correct
   - Check redirect URL matches server configuration
   - Ensure all OAuth endpoints are accessible

3. **Session Not Persisting**
   - Check secure storage permissions
   - Verify the app has necessary platform permissions

## Support

For issues or questions about the flutter_certilia SDK, please visit the [GitHub repository](https://github.com/your-repo/flutter_certilia).