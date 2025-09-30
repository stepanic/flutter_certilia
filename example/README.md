# flutter_certilia Example

This example demonstrates how to use the flutter_certilia SDK in a clean client-server architecture.

## Architecture

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│  Flutter Client │────▶│  Backend Server  │────▶│  Certilia API   │
│                 │◀────│  (Node.js Proxy) │◀────│                 │
└─────────────────┘     └──────────────────┘     └─────────────────┘
        
Flutter knows only      Server handles all       Official OAuth
about YOUR server      OAuth communication      Provider
```

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

The example demonstrates the simplified client-server architecture where the Flutter client only needs to know about your backend server:

```dart
// Simple client configuration - Flutter only needs to know about YOUR server
final client = await CertiliaSDKSimple.initialize(
  clientId: '991dffbb1cdd4d51423e1a5de323f13b15256c63',
  serverUrl: 'https://your-backend-server.com',
  scopes: ['openid', 'profile', 'eid', 'email', 'offline_access'],
  enableLogging: true,
);
```

The backend server handles:
- All OAuth communication with Certilia API
- Token management and refresh
- User info retrieval
- Security and API credentials

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