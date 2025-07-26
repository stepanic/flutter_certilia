# AppAuth Migration Guide

This document explains the migration from WebView-based authentication to AppAuth for improved security and eIDAS compliance.

## What Changed

### Before (WebView)
- Authentication was handled in an embedded WebView
- Security concerns: cookies and sessions could be intercepted
- Not compliant with eIDAS requirements for high-security authentication

### After (AppAuth)
- Authentication uses the system's native browser
- Improved security: isolated browser context
- Full PKCE (Proof Key for Code Exchange) support
- eIDAS compliant for Croatian eID authentication

## Platform Configuration

### Android

Add the following to `android/app/src/main/AndroidManifest.xml`:

```xml
<!-- AppAuth Redirect Activity -->
<activity
    android:name="net.openid.appauth.RedirectUriReceiverActivity"
    android:exported="true"
    android:theme="@android:style/Theme.NoDisplay">
    <intent-filter>
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.DEFAULT" />
        <category android:name="android.intent.category.BROWSABLE" />
        <data android:scheme="com.example.certilia" 
              android:host="oauth" />
    </intent-filter>
</activity>
```

### iOS

Add the following to `ios/Runner/Info.plist`:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>com.example.certilia</string>
        </array>
    </dict>
</array>
```

## Code Changes

### Configuration

```dart
// Before (WebView with server)
const config = CertiliaConfig(
  clientId: 'your-client-id',
  redirectUrl: 'https://your-server.com/api/auth/callback',
  scopes: ['openid', 'profile', 'eid', 'email', 'offline_access'],
);

// After (AppAuth with custom scheme)
const config = CertiliaConfig(
  clientId: 'your-client-id',
  redirectUrl: 'com.example.certilia://oauth',  // Custom URL scheme
  scopes: ['openid', 'profile', 'eid', 'email', 'offline_access'],
);
```

### Client Initialization

```dart
// The API remains the same
final certilia = CertiliaUniversalClient(
  config: config,
  // serverUrl is optional - only needed for extended user info
  serverUrl: 'https://your-server.com',
);
```

## Features Maintained

All existing features continue to work:
- ✅ Authentication with Croatian eID
- ✅ Token refresh
- ✅ Persistent authentication
- ✅ Extended user information (requires server)
- ✅ Automatic logout on token expiration
- ✅ Multi-language support

## Security Improvements

1. **No Cookie Access**: AppAuth uses native browser, preventing cookie theft
2. **PKCE by Default**: Automatic PKCE implementation for enhanced security
3. **Session Isolation**: Each auth session is isolated from other apps
4. **eIDAS Compliance**: Meets EU standards for electronic identification

## Migration Steps

1. Update your `pubspec.yaml` (already includes `flutter_appauth`)
2. Add platform-specific configuration (see above)
3. Update your redirect URL to use custom scheme
4. Test on both Android and iOS devices

## Troubleshooting

### "Authentication was cancelled"
- User closed the browser without completing authentication
- Check that your redirect URL matches exactly in Certilia admin

### "Invalid redirect URI"
- Ensure the custom scheme is registered in platform config
- Verify the redirect URL is whitelisted in Certilia settings

### Extended user info not working
- The `serverUrl` parameter is still required for extended info
- This endpoint requires your Node.js middleware server

## Backwards Compatibility

The web platform still uses the popup-based authentication for compatibility with browsers that don't support custom URL schemes.