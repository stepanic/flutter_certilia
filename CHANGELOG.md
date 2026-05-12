## 0.2.0

Major refactor for production readiness and reuse as a drop-in
"Login with Certilia" component. The SDK is now proxy-only — all OAuth
communication goes through a backend (`certilia-server`).

### Breaking changes

* `CertiliaSDKSimple` renamed to `CertiliaSDK`. Deprecated typedef kept.
* `CertiliaConfigSimple` renamed to `CertiliaConfig`. Deprecated typedef
  kept. The old full-featured `CertiliaConfig` (with `clientId`,
  `redirectUrl`, `baseUrl`, `authorizationEndpoint`, ...) has been
  removed — the proxy server holds these now.
* `CertiliaClient` (deprecated since 0.1) removed.
* `sessionTimeout` parameter removed from `CertiliaSDK.initialize` and
  `CertiliaConfig` — it was never enforced. Token expiry on the
  Certilia tokens themselves is the source of truth for session
  lifetime.
* Minimum Dart bumped to `>=3.2.0`, minimum Flutter to `>=3.16.0`.

### Removed

* `flutter_appauth` dependency — the native-browser auth path was never
  shippable because Certilia rejects custom URL schemes. Now external
  dep-free apart from `http`, `flutter_secure_storage`, and
  `webview_flutter`.
* `url_launcher` dependency — same reason.
* AppAuth client, manual OAuth client, universal client, deprecated
  `CertiliaClient`, the legacy "full" SDK entry point. Public API is
  now a single entry point + five models/exceptions.

### Added

* `ProxyAuthService` — internal HTTP service through which both the
  WebView (mobile/desktop) and web-popup (web) clients communicate
  with the proxy. Single source of retry, timeout, and header policy.
* Test suite expanded from 10 to 46 assertions, covering
  `ProxyAuthService`, `CertiliaToken` expiry / JSON roundtrip, and
  `CertiliaConfig` validation. Uses `package:http/testing` `MockClient`
  for proxy simulation.
* `example/lib/main.dart` reads server URL from
  `--dart-define=CERTILIA_SERVER_URL=...` so a fresh checkout doesn't
  bake a dev tunnel into the binary.

### Fixed

* **Async init race**: the previous releases kicked off token-load
  futures from constructors without waiting. Public methods called
  before that future resolved (notably right after a hot restart with
  a saved session) would briefly report "not authenticated". All
  async public methods now `await` the constructor's init future.
* **Refresh-flow auth shape**: refresh used to send the current access
  token in `Authorization: Bearer ...` — semantically wrong, since
  refresh is an unauthenticated token-for-token exchange. Both tokens
  now travel in the JSON body. The proxy server still accepts the old
  Authorization-header shape for backward compatibility.
* **Web CORS**: the `ngrok-skip-browser-warning` header used to be
  sent on all platforms. On web it triggered a CORS preflight that
  the proxy server's allow-list rejected, blocking every request. The
  header is now sent only on non-web platforms.
* Ngrok TLS-bypass code from the manual OAuth client (which
  unconditionally accepted any `*.ngrok-free.app` certificate) is
  gone with the file.

## 0.1.0

* Initial release of flutter_certilia
* OAuth 2.0 authentication with PKCE support
* Croatian eID (eOsobna) integration through NIAS system
* Support for iOS, Android, and Web platforms
* Automatic token refresh functionality
* Secure token storage using flutter_secure_storage
* Comprehensive error handling with custom exceptions
* Debug logging support
