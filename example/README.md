# Flutter Certilia Example Apps

This directory contains example applications demonstrating different ways to integrate Certilia authentication in your Flutter app.

## Available Examples

### 1. Direct OAuth Flow (main.dart)
Uses `flutter_appauth` to perform OAuth authentication directly with Certilia. This opens an external browser for authentication.

**Pros:**
- Simple implementation
- Direct connection to Certilia
- No middleware server required

**Cons:**
- Opens external browser (not in-app)
- Limited control over authentication UI
- May not work on all platforms (e.g., web)

### 2. Server Middleware Flow (main_server.dart)
Uses a Node.js server as middleware between the Flutter app and Certilia API. Still opens external browser but through server-managed flow.

**Pros:**
- Server handles OAuth complexity
- Can add custom business logic
- Better security (client secret on server)

**Cons:**
- Requires running server
- Still opens external browser
- More complex setup

### 3. WebView In-App Flow (main_webview.dart) ⭐ RECOMMENDED
Uses WebView to perform authentication entirely within the app, providing the best user experience.

**Pros:**
- Authentication happens in-app
- Full control over UI/UX
- Works on all platforms
- Better user experience
- No app switching

**Cons:**
- Requires server middleware
- Slightly more complex implementation

## Running the Examples

### Prerequisites

1. **For all examples:**
   ```bash
   flutter pub get
   ```

2. **For server-based examples (main_server.dart, main_webview.dart):**
   - Start the Certilia server:
     ```bash
     cd ../certilia-server
     ./dev-start.sh
     ```
   - Ensure ngrok is running with the correct domain

### Running Different Examples

1. **Direct OAuth Flow:**
   ```bash
   flutter run -t lib/main.dart
   ```

2. **Server Middleware Flow:**
   ```bash
   flutter run -t lib/main_server.dart
   ```

3. **WebView In-App Flow:**
   ```bash
   flutter run -t lib/main_webview.dart
   ```

## Configuration

### Direct OAuth (main.dart)
```dart
const config = CertiliaConfig(
  clientId: 'your_client_id_here',
  redirectUrl: 'com.example.certilia://callback',
  scopes: ['openid', 'profile', 'eid'],
);
```

### Server-based (main_server.dart, main_webview.dart)
```dart
// Update server URL to match your setup
static const String serverUrl = 'https://uniformly-credible-opossum.ngrok-free.app';
static const String clientId = 'your_client_id';
```

## Platform-specific Setup

### iOS
Add to `ios/Runner/Info.plist`:
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

### Android
Add to `android/app/src/main/AndroidManifest.xml`:
```xml
<intent-filter>
  <action android:name="android.intent.action.VIEW" />
  <category android:name="android.intent.category.DEFAULT" />
  <category android:name="android.intent.category.BROWSABLE" />
  <data android:scheme="com.example.certilia" />
</intent-filter>
```

### Web
For WebView support, ensure your server has proper CORS configuration.

### 4. Universal Cross-Platform Flow (main_universal.dart) ⭐ BEST FOR PRODUCTION
Uses platform-specific authentication methods automatically:
- **Web**: Opens popup window
- **iOS/Android**: Uses in-app WebView

**Pros:**
- Single codebase for all platforms
- Automatic platform detection
- Best user experience per platform
- Production-ready

**Usage:**
```bash
flutter run -t lib/main_universal.dart
```

## Testing

### Unit Tests
Run widget and unit tests:
```bash
flutter test
```

### Integration Tests

#### Automated E2E Testing
Use the test runner script:
```bash
cd integration_test
./e2e_test_runner.sh

# Or run specific platform tests:
./e2e_test_runner.sh chrome    # Web tests
./e2e_test_runner.sh ios       # iOS tests
./e2e_test_runner.sh android   # Android tests
./e2e_test_runner.sh all       # All platforms
```

#### Manual Integration Tests
1. **Chrome/Web:**
   ```bash
   flutter drive \
     --driver=test_driver/integration_test.dart \
     --target=integration_test/oauth_flow_test.dart \
     -d chrome
   ```

2. **iOS:**
   ```bash
   flutter test integration_test/oauth_flow_test.dart
   ```

3. **Android:**
   ```bash
   flutter test integration_test/oauth_flow_test.dart
   ```

### Test Coverage
The tests cover:
- Initial authentication state
- Sign in button functionality
- Loading states
- Successful authentication flow
- Error handling
- Logout functionality
- Token refresh
- Platform-specific behavior

## Troubleshooting

1. **"Server not responding" error:**
   - Check that certilia-server is running
   - Verify ngrok is running with correct domain
   - Check server URL in the example code

2. **WebView not loading:**
   - Ensure you have internet permission on Android
   - Check that JavaScript is enabled in WebView
   - Verify server SSL certificate is valid

3. **Authentication fails:**
   - Verify client ID is correct
   - Check that redirect URLs match configuration
   - Ensure all required scopes are requested

4. **Tests failing:**
   - Ensure server is running before running integration tests
   - Check that all dependencies are installed
   - Verify device/emulator is properly configured