# flutter_certilia_example

Example application demonstrating the usage of flutter_certilia package.

## Getting Started

1. Replace `your_client_id_here` in `lib/main.dart` with your actual Certilia client ID
2. Update the redirect URL to match your app's configuration
3. Configure platform-specific settings as described below

## Platform Configuration

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

### Android

Add the following to `android/app/build.gradle`:

```gradle
android {
    defaultConfig {
        manifestPlaceholders += [
            'appAuthRedirectScheme': 'com.example.certilia'
        ]
    }
}
```

## Running the Example

```bash
flutter pub get
flutter run
```

## Features Demonstrated

- OAuth 2.0 authentication flow
- Displaying user information
- Logout functionality
- End session functionality
- Error handling
- Loading states