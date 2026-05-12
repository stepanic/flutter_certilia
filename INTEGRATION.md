# Integration: dropping `flutter_certilia` into another app

Five steps from a fresh Flutter project to a working "Login with
Certilia" button. Assumes you already have a running `certilia-server`
(see [`certilia-server/README.md`](certilia-server/README.md)).

## 1. Add the dependency

In your app's `pubspec.yaml`:

```yaml
dependencies:
  flutter_certilia:
    git:
      url: https://github.com/stepanic/flutter_certilia.git
      ref: main
```

For local-loop development, `path:` works too:

```yaml
dependencies:
  flutter_certilia:
    path: ../flutter_certilia
```

Requirements: Dart `>=3.2.0`, Flutter `>=3.16.0`.

## 2. Configure the proxy URL

The SDK only needs to know where your `certilia-server` lives.
Don't bake that URL into your source — read it from `--dart-define`:

```dart
const _serverUrl = String.fromEnvironment(
  'CERTILIA_SERVER_URL',
  defaultValue: 'https://your-default.example',
);
```

Override per build:

```bash
flutter run --dart-define=CERTILIA_SERVER_URL=https://your-proxy.example
flutter build apk --dart-define=CERTILIA_SERVER_URL=https://prod-proxy.example
```

## 3. Initialize and authenticate

```dart
import 'package:flutter/material.dart';
import 'package:flutter_certilia/flutter_certilia.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  dynamic _certilia;
  CertiliaUser? _user;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _certilia = await CertiliaSDK.initialize(
      serverUrl: _serverUrl,
      scopes: const ['openid', 'profile', 'eid', 'email', 'offline_access'],
      enableLogging: true,
    );
    if (await _certilia.checkAuthenticationStatus()) {
      setState(() async => _user = await _certilia.getCurrentUser());
    }
  }

  Future<void> _login() async {
    try {
      final user = await _certilia.authenticate(context);
      setState(() => _user = user);
    } on CertiliaAuthenticationException {
      // user cancelled or upstream rejected
    } on CertiliaNetworkException catch (e) {
      // HTTP error reaching the proxy — show e.statusCode / e.message
    }
  }

  Future<void> _logout() async {
    await _certilia.logout();
    setState(() => _user = null);
  }

  @override
  Widget build(BuildContext context) {
    if (_user == null) {
      return Center(
        child: ElevatedButton(
          onPressed: _login,
          child: const Text('Login with Certilia'),
        ),
      );
    }
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Hello, ${_user!.fullName ?? _user!.sub}'),
          if (_user!.oib != null) Text('OIB: ${_user!.oib}'),
          ElevatedButton(onPressed: _logout, child: const Text('Logout')),
        ],
      ),
    );
  }
}
```

## 4. Wire it into your app

```dart
void main() => runApp(const MaterialApp(home: LoginScreen()));
```

That's the minimum. On web the SDK opens a popup against your proxy; on
mobile/desktop it pushes a full-screen `WebView` route. Both close
themselves on success and return control to your screen.

## 5. (Optional) Use the example UI as a starting point

The `example/lib/certilia_auth/` directory in this repo contains a
fuller reference UI: themed login button with the official Certilia
artwork, post-auth dashboard with user-info cards, language toggle, and
the "what extended fields are available?" introspection card. Copy
what you need, drop the rest.

It does **not** ship in the SDK package — it's intentionally outside
`lib/` so it doesn't constrain your design system.

## Troubleshooting checklist

- **Login button does nothing** → check the proxy URL is reachable
  from the browser/device (open it manually).
- **CORS errors on web** → your proxy's CORS allow-list needs your
  app's origin. The SDK already avoids custom request headers on web
  to keep CORS minimal.
- **"Authentication was cancelled"** → user closed the popup/WebView,
  or popup was blocked. On web, ensure popups are allowed for your
  origin.
- **Logged in but `getCurrentUser` returns null right after restart**
  → this was a real race fixed in 0.2.0. If you see it on 0.2.0+
  open an issue.
- **`refreshToken` fails with 400** → server may need to be updated
  for the 0.2.0 body-shape refresh contract. The 0.2.0+ server
  accepts both old (header) and new (body) shapes; older versions
  expect only the header form.

See [`README.md`](README.md) for the full public-API surface and
[`CLAUDE.md`](CLAUDE.md) for SDK-internal architecture.
