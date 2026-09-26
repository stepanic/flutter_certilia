## Unreleased

### Added

* `callbackUrl` in `CertiliaSDK.initialize` and `CertiliaConfig`: Certilia
  redirects to the app instead of the proxy. On mobile the login runs in
  the system browser through `flutter_web_auth_2` (Android Auth Tab or
  Custom Tabs, iOS `ASWebAuthenticationSession`) with a custom-scheme or
  https App Link / Universal Link callback. On web a callback page on the
  app's origin (`example/web/certilia_callback.html`) reports the result
  over BroadcastChannel and localStorage.
* Direct mode (`CertiliaDirectClient`): the app holds the Certilia client
  and talks to Certilia without `certilia-server`. It requires an https
  callback, and the SDK verifies the ID token against Certilia's JWKS.
  Adds the `crypto` and `pointycastle` dependencies.
* certilia-server: `CERTILIA_CLIENTS` registers more Certilia clients,
  one per callback URL; the proxy picks the client by the `redirect_uri`
  the app sends.

### Changed

* Web: the popup opens blank before the first network request, because
  Safari and every browser on iOS block `window.open` once the page has
  waited on the network after the tap.
* `CertiliaUser.oib` and `CertiliaExtendedInfo.oib` fall back to `sub`
  when it is a valid OIB; Certilia's portal clients send the OIB only as
  the subject.
* `getCurrentUser()` on mobile ends the session and returns null when
  Certilia or the proxy refuses the refresh. A timeout or server error
  keeps the session and throws.

### Removed

* The web popup flow that polled the proxy for the code, with the
  proxy's `/api/auth/polling/*` endpoints and `ProxyAuthService`'s polling
  methods. Whoever polled received the code, so anyone could start a login
  on a deployed proxy, send a user the Certilia link and collect that
  user's code. On web, `callbackUrl` is now required.

### Security

* certilia-server: the callback page no longer posts the authorization
  code to `window.opener`; it went to any page that had opened it.
* certilia-server: `/api/auth/refresh` verifies the access token it copies
  claims from, so a refresh token can no longer get arbitrary claims
  signed. The refreshed token keeps the user's claims.

### Fixed

* `CertiliaUser.hashCode` agrees with `==`.
* Android: the login tab no longer stays open above the app after the
  redirect; `preferEphemeralSession` is passed to the browser only on
  iOS and macOS.

## 0.2.0

Refactor for reuse as a "Login with Certilia" component in other apps.
All OAuth communication goes through a backend (`certilia-server`).

### Breaking changes

* `CertiliaSDKSimple` renamed to `CertiliaSDK`. Deprecated typedef kept.
* `CertiliaConfigSimple` renamed to `CertiliaConfig`. Deprecated typedef
  kept. The old full-featured `CertiliaConfig` (with `clientId`,
  `redirectUrl`, `baseUrl`, `authorizationEndpoint`, ...) has been
  removed; the proxy server holds these now.
* `CertiliaClient` (deprecated since 0.1) removed.
* `sessionTimeout` parameter removed from `CertiliaSDK.initialize` and
  `CertiliaConfig`: it was never enforced. A session lasts as long as
  its Certilia tokens are valid.
* Minimum Dart bumped to `>=3.2.0`, minimum Flutter to `>=3.16.0`.

### Removed

* `flutter_appauth` and `url_launcher` dependencies, which only the
  removed AppAuth and manual OAuth clients used. The remaining
  dependencies are `http`, `flutter_secure_storage` and
  `webview_flutter`.
* AppAuth client, manual OAuth client, universal client, deprecated
  `CertiliaClient`, the legacy "full" SDK entry point. Public API is
  now a single entry point + five models/exceptions.

### Added

* `ProxyAuthService`: internal HTTP service through which both the
  WebView (mobile/desktop) and web-popup (web) clients communicate
  with the proxy. It sets the retries, timeouts and headers of every
  proxy request.
* Test suite expanded from 10 to 46 assertions, covering
  `ProxyAuthService`, `CertiliaToken` expiry / JSON roundtrip, and
  `CertiliaConfig` validation. Uses `package:http/testing` `MockClient`
  for proxy simulation.
* `example/lib/main.dart` reads server URL from
  `--dart-define=CERTILIA_SERVER_URL=...`, so a new checkout does not
  build a developer's tunnel URL into the app.

### Fixed

* **Async init race**: the previous releases kicked off token-load
  futures from constructors without waiting. Public methods called
  before that future resolved (notably right after a hot restart with
  a saved session) would briefly report "not authenticated". All
  async public methods now `await` the constructor's init future.
* **Refresh request**: refresh used to send the current access
  token in `Authorization: Bearer ...`, which is semantically wrong, since
  refresh is an unauthenticated token-for-token exchange. Both tokens
  now travel in the JSON body. The proxy server still accepts the old
  Authorization header for backward compatibility.
* **Web CORS**: the `ngrok-skip-browser-warning` header used to be
  sent on all platforms. On web it triggered a CORS preflight that
  the proxy server's allow-list rejected, blocking every request. The
  header is now sent only on non-web platforms.
* The manual OAuth client accepted any `*.ngrok-free.app` TLS
  certificate; that code was removed with the client.

## 0.1.0

* Initial release of flutter_certilia
* OAuth 2.0 authentication with PKCE support
* Croatian eID (eOsobna) integration through NIAS system
* Support for iOS, Android, and Web platforms
* Automatic token refresh
* Secure token storage using flutter_secure_storage
* Custom exception classes
* Debug logging support
