# Deep Link Setup for AppAuth with HTTPS Redirect

This guide explains how to configure your Flutter app to handle HTTPS redirects with AppAuth using App Links (Android) and Universal Links (iOS).

## Why HTTPS Instead of Custom Schemes?

Using HTTPS URLs for OAuth redirects provides better security and maintains consistency with web-based authentication flows. Both Android and iOS support intercepting HTTPS URLs through App Links and Universal Links.

## Android Configuration

### 1. AndroidManifest.xml

The AppAuth redirect activity is configured to handle HTTPS URLs:

```xml
<activity
    android:name="net.openid.appauth.RedirectUriReceiverActivity"
    android:exported="true"
    android:theme="@android:style/Theme.NoDisplay">
    <intent-filter android:autoVerify="true">
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.DEFAULT" />
        <category android:name="android.intent.category.BROWSABLE" />
        <data android:scheme="https" 
              android:host="your-server.com"
              android:pathPrefix="/api/auth/callback" />
    </intent-filter>
</activity>
```

### 2. Digital Asset Links

Create `/.well-known/assetlinks.json` on your server:

```json
[
  {
    "relation": ["delegate_permission/common.handle_all_urls"],
    "target": {
      "namespace": "android_app",
      "package_name": "com.example.flutter_certilia_example",
      "sha256_cert_fingerprints": [
        "YOUR_APP_SHA256_FINGERPRINT"
      ]
    }
  }
]
```

To get your SHA256 fingerprint:
```bash
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
```

## iOS Configuration

### 1. Info.plist

Enable Flutter deep linking:

```xml
<key>FlutterDeepLinkingEnabled</key>
<true/>
```

### 2. Entitlements

Create `Runner.entitlements` with associated domains:

```xml
<key>com.apple.developer.associated-domains</key>
<array>
    <string>applinks:your-server.com</string>
</array>
```

### 3. Apple App Site Association

Create `/.well-known/apple-app-site-association` on your server:

```json
{
  "applinks": {
    "apps": [],
    "details": [
      {
        "appID": "TEAM_ID.com.example.flutterCertiliaExample",
        "paths": ["/api/auth/callback*"]
      }
    ]
  }
}
```

## Server Configuration

Your server must:

1. Serve the `.well-known` files with correct content-type
2. Be accessible via HTTPS
3. Not redirect these files

Example Express.js configuration:

```javascript
app.get('/.well-known/apple-app-site-association', (req, res) => {
  res.type('application/json');
  res.sendFile('path/to/apple-app-site-association');
});

app.get('/.well-known/assetlinks.json', (req, res) => {
  res.type('application/json');
  res.sendFile('path/to/assetlinks.json');
});
```

## Testing

### Android
1. Install the app on a device
2. Visit: `https://your-server.com/.well-known/assetlinks.json`
3. Try authentication - the redirect should open your app

### iOS
1. Install the app on a device
2. Visit: `https://your-server.com/.well-known/apple-app-site-association`
3. Try authentication - the redirect should open your app

## Troubleshooting

### Android
- Ensure `android:autoVerify="true"` is set
- Check SHA256 fingerprint matches
- Use `adb shell pm get-app-links com.example.flutter_certilia_example`

### iOS
- Ensure provisioning profile includes associated domains
- Check Team ID is correct
- Use Console app to check for swcd errors

## Important Notes

1. **HTTPS Required**: Both platforms require valid HTTPS certificates
2. **No Redirects**: The `.well-known` files must be served directly
3. **Testing**: Use real devices for testing (simulators may not work)
4. **Ngrok**: When using ngrok, the URLs change - update configurations accordingly