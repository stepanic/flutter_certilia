# flutter_certilia - Detaljna Analiza Codebase-a

## 📋 Pregled Projekta

**flutter_certilia** je Flutter SDK za integraciju s Certilia Identity API-jem koji omogućava OAuth 2.0 autentifikaciju pomoću hrvatske elektroničke osobne iskaznice (eOsobna) kroz NIAS sustav.

- **Verzija**: 0.1.0
- **Licenca**: MIT
- **Repozitorij**: https://github.com/stepanic/flutter_certilia
- **Dart SDK**: >=2.19.0 <4.0.0
- **Flutter**: >=3.0.0

---

## 🏗️ Arhitektura Projekta

### Client-Server Arhitektura

Projekt podržava **dva načina implementacije**:

#### 1. Preporučena: Client-Server Arhitektura (CertiliaSDKSimple)
```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│  Flutter Client │────▶│  Backend Server  │────▶│  Certilia API   │
│                 │◀────│  (Node.js Proxy) │◀────│                 │
└─────────────────┘     └──────────────────┘     └─────────────────┘

Flutter zna samo       Server upravlja svom      Službeni OAuth
o VAŠEM serveru       OAuth komunikacijom        Provider
```

**Prednosti:**
- ✅ API kredencijali ostaju sigurni na serveru
- ✅ Pojednostavljena konfiguracija Flutter klijenta
- ✅ Centralizirano upravljanje OAuth tokom
- ✅ Bolja sigurnost i kontrola

#### 2. Direktna Integracija (CertiliaSDK)
```
┌─────────────────┐     ┌─────────────────┐
│  Flutter Client │────▶│  Certilia API   │
│                 │◀────│                 │
└─────────────────┘     └─────────────────┘

Flutter direktno        Službeni OAuth
komunicira s API-jem    Provider
```

**Napomena**: Nije preporučeno za produkciju jer zahtijeva hardkodiranje API kredencijala u Flutter aplikaciji.

---

## 📁 Struktura Projekta

```
flutter_certilia/
├── lib/
│   ├── flutter_certilia.dart          # Glavni export file
│   └── src/
│       ├── certilia_sdk.dart           # SDK s punom konfiguracijom
│       ├── certilia_sdk_simple.dart    # Pojednostavljeni SDK (preporučeno)
│       ├── certilia_sdk_factory.dart   # Platform factory (mobile/desktop)
│       ├── certilia_sdk_factory_web.dart # Platform factory (web)
│       ├── certilia_client.dart        # Base client interface
│       ├── certilia_universal_client.dart # Universal client wrapper
│       ├── certilia_appauth_client.dart # AppAuth implementacija (iOS/Android)
│       ├── certilia_manual_oauth_client.dart # Manual OAuth za mobile
│       ├── certilia_webview_client.dart # WebView implementacija
│       ├── certilia_web_client.dart    # Web popup implementacija
│       ├── certilia_web_client_polling.dart # Web polling implementacija
│       ├── certilia_client_stub.dart   # Stub za conditional exports
│       ├── constants.dart              # Konstante (baseUrl, endpointi)
│       ├── models/
│       │   ├── certilia_config.dart           # Puna konfiguracija
│       │   ├── certilia_config_simple.dart    # Pojednostavljena konfiguracija
│       │   ├── certilia_user.dart             # User model
│       │   ├── certilia_token.dart            # Token model
│       │   └── certilia_extended_info.dart    # Extended info model
│       └── exceptions/
│           └── certilia_exception.dart # Custom exception tipovi
│
├── example/                            # Primjer aplikacije
│   ├── lib/
│   │   └── main.dart                   # Demo app s client-server pristupom
│   └── README.md                       # Dokumentacija primjera
│
├── test/                               # Unit testovi
│   ├── flutter_certilia_test.dart
│   ├── certilia_client_test.dart
│   ├── certilia_client_test.mocks.dart
│   ├── utils/validators_test.dart
│   └── models/certilia_user_test.dart
│
├── certilia-server/                    # Node.js backend proxy server
│   ├── server.js                       # Express server
│   ├── CERTILIA_OAUTH_SETUP.md        # OAuth setup dokumentacija
│   └── DEVELOPMENT.md                  # Development guide
│
├── README.md                           # Glavna dokumentacija
├── SDK_INTEGRATION_PLAN.md            # Plan SDK integracije
├── APPAUTH_MIGRATION.md               # AppAuth migracija guide
├── CHANGELOG.md                        # Changelog
└── pubspec.yaml                        # Dart dependencies
```

---

## 🔧 Glavne Komponente

### 1. SDK Entry Points

#### CertiliaSDKSimple (lib/src/certilia_sdk_simple.dart)
**Svrha**: Pojednostavljeni SDK za client-server arhitekturu

**Ključne značajke:**
- Inicijalizacija s minimalnim parametrima
- Flutter klijent komunicira samo s vašim backend serverom
- Backend upravlja svim OAuth komunikacijama s Certilia API-jem
- Automatski odabir platformski specifične implementacije

**Konfiguracija:**
```dart
final client = await CertiliaSDKSimple.initialize(
  clientId: 'your_client_id',
  serverUrl: 'https://your-backend-server.com',
  scopes: ['openid', 'profile', 'eid', 'email', 'offline_access'],
  enableLogging: true,
  sessionTimeout: 3600000, // 1 sat
);
```

**Interne odluke:**
- Web platforma → koristi `CertiliaWebClient` (popup)
- Mobile/Desktop → koristi `CertiliaWebViewClient` (in-app WebView)

#### CertiliaSDK (lib/src/certilia_sdk.dart)
**Svrha**: Potpuni SDK s direktnom Certilia integracijom

**Ključne značajke:**
- Puna konfiguracija s svim OAuth endpointima
- Direktna komunikacija s Certilia API-jem
- Factory method za kreiranje basic konfiguracije
- Platform auto-detection

**Konfiguracija:**
```dart
final certilia = await CertiliaSDK.initialize(
  config: CertiliaConfig(
    clientId: 'your_client_id',
    redirectUrl: 'com.example.app://callback',
    baseUrl: 'https://idp.test.certilia.com',
    authorizationEndpoint: 'https://idp.test.certilia.com/oauth2/authorize',
    tokenEndpoint: 'https://idp.test.certilia.com/oauth2/token',
    userInfoEndpoint: 'https://idp.test.certilia.com/oauth2/userinfo',
    scopes: ['openid', 'profile', 'eid'],
  ),
  forceWebView: false, // Optional
);
```

**Platform odluke:**
- Web (`kIsWeb`) → `CertiliaWebClient` (obavezno server URL)
- `forceWebView == true` → `CertiliaWebViewClient` (obavezno server URL)
- Inače → `CertiliaUniversalClient` (AppAuth s WebView fallback)

---

### 2. Platform Implementacije

#### CertiliaUniversalClient (lib/src/certilia_universal_client.dart)
**Svrha**: Univerzalni wrapper koji automatski bira pravu implementaciju

**Platform mapping:**
- iOS/Android → `CertiliaManualOAuthClient` (via conditional import)
- Web → `CertiliaWebClient` (via conditional import)
- Fallback → `CertiliaClientStub` (throw error)

**API metode:**
- `authenticate(BuildContext context)` → CertiliaUser
- `checkAuthenticationStatus()` → Future<bool>
- `getCurrentUser()` → Future<CertiliaUser?>
- `refreshToken()` → Future<void>
- `logout()` → Future<void>
- `getExtendedUserInfo()` → Future<CertiliaExtendedInfo?>
- Getters: `currentAccessToken`, `currentRefreshToken`, `currentIdToken`, `tokenExpiry`

#### CertiliaWebViewClient (lib/src/certilia_webview_client.dart)
**Svrha**: WebView-based autentifikacija za mobile/desktop

**Ključne značajke:**
- Otvara autentifikaciju u in-app WebView-u
- Komunikacija kroz backend proxy server
- Automatsko spremanje tokena u FlutterSecureStorage
- Token refresh logika s retry mehanizmom
- Auto-close WebView-a nakon callback-a
- 80% zoom za bolje korisničko iskustvo
- Session persistence preko app restarta

**OAuth Flow:**
1. `_initializeOAuthFlow()` → GET /api/auth/initialize → dobiva authorization_url, state, session_id
2. `_showAuthWebView()` → Prikazuje WebView s authorization_url
3. WebView prati redirect_url s kodom
4. `_exchangeCodeForTokens()` → POST /api/auth/exchange → dobiva access_token, refresh_token, id_token
5. Sprema tokene u secure storage
6. `_fetchUserInfo()` → GET /api/auth/user → dobiva user podatke

**Retry logika:**
- Token exchange pokušava 3 puta s exponential backoff
- Timeout: 30 sekundi po pokušaju

**Extended User Info:**
- GET /api/user/extended-info → vraća CertiliaExtendedInfo s svim dostupnim poljima
- Automatski refresh ako token istekne (status 401/502)
- Auto-logout ako refresh ne uspije

#### CertiliaAppAuthClient (lib/src/certilia_appauth_client.dart)
**Svrha**: Native browser OAuth za iOS/Android koristeći flutter_appauth

**Ključne značajke:**
- Koristi native browser umjesto WebView-a
- PKCE (Proof Key for Code Exchange) podrška
- eIDAS compliant
- Bolja sigurnost - izoliran browser context

**Konfiguracija:**
- iOS: Zahtijeva CFBundleURLSchemes u Info.plist
- Android: Zahtijeva RedirectUriReceiverActivity u AndroidManifest.xml

**OAuth Flow:**
- Standard OAuth 2.0 Authorization Code Flow s PKCE
- Automatski generira code_verifier i code_challenge

#### CertiliaWebClient (lib/src/certilia_web_client.dart)
**Svrha**: Web popup autentifikacija

**Ključne značajke:**
- Otvara autentifikaciju u popup prozoru (width: 500, height: 700)
- Polling mehanizam za detekciju completion-a
- Auto-close popup-a nakon uspješne autentifikacije
- Cross-origin komunikacija s backend serverom

**Polling logic:**
- Provjerava svake 2 sekunde je li popup zatvoren
- Provjerava svake 2 sekunde je li autentifikacija završena na serveru

---

### 3. Data Modeli

#### CertiliaConfig (lib/src/models/certilia_config.dart)
**Svrha**: Puna OAuth konfiguracija

**Polja:**
```dart
class CertiliaConfig {
  final String clientId;                    // OAuth client ID
  final String? clientSecret;               // OAuth client secret (optional)
  final String redirectUrl;                 // OAuth redirect URL
  final List<String> scopes;                // OAuth scopes
  final String baseUrl;                     // Certilia IDP base URL
  final String authorizationEndpoint;       // OAuth authorize endpoint
  final String tokenEndpoint;               // OAuth token endpoint
  final String userInfoEndpoint;            // OAuth userinfo endpoint
  final String? discoveryUrl;               // OIDC discovery URL (optional)
  final String? serverUrl;                  // Backend server URL (optional)
  final bool preferEphemeralSession;        // iOS ephemeral session
  final bool enableLogging;                 // Debug logging
  final String? customUserAgent;            // Custom UA string
  final int? sessionTimeout;                // Session timeout (ms)
  final int? refreshTokenTimeout;           // Refresh token timeout (ms)
}
```

**Default values:**
- `scopes`: `['openid', 'profile', 'eid']`
- `baseUrl`: `'https://idp.test.certilia.com'`
- `preferEphemeralSession`: `true`
- `enableLogging`: `false`

**Validacija:**
- clientId ne može biti prazan
- redirectUrl mora sadržavati '://'
- scopes ne može biti prazan

#### CertiliaConfigSimple (lib/src/models/certilia_config_simple.dart)
**Svrha**: Pojednostavljena konfiguracija za client-server

**Polja:**
```dart
class CertiliaConfigSimple {
  final String clientId;                    // OAuth client ID
  final String serverUrl;                   // Backend server URL
  final String redirectUrl;                 // OAuth redirect URL
  final List<String> scopes;                // OAuth scopes
  final bool preferEphemeralSession;        // iOS ephemeral session
  final bool enableLogging;                 // Debug logging
  final int? sessionTimeout;                // Session timeout (ms)
}
```

**Default scopes**: `['openid', 'profile', 'eid']`

#### CertiliaUser (lib/src/models/certilia_user.dart)
**Svrha**: Korisničke informacije iz OAuth userinfo endpointa

**Polja:**
```dart
class CertiliaUser {
  final String sub;                         // Unique user ID
  final String? firstName;                  // Ime
  final String? lastName;                   // Prezime
  final String? oib;                        // Hrvatski OIB
  final String? email;                      // Email adresa
  final DateTime? dateOfBirth;              // Datum rođenja

  // Computed
  String? get fullName => '$firstName $lastName';
}
```

**JSON mapping:**
- `sub` ← `sub`
- `firstName` ← `given_name` ili `first_name`
- `lastName` ← `family_name` ili `last_name`
- `email` ← `email`
- `oib` ← `oib`
- `dateOfBirth` ← `birthdate` (ISO 8601 format)

#### CertiliaToken (lib/src/models/certilia_token.dart)
**Svrha**: OAuth token reprezentacija

**Polja:**
```dart
class CertiliaToken {
  final String accessToken;                 // Access token
  final String? refreshToken;               // Refresh token (optional)
  final String? idToken;                    // ID token (optional)
  final DateTime? expiresAt;                // Token expiry time
  final String tokenType;                   // Token type (obično 'Bearer')

  // Computed
  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);
}
```

**JSON serialization**: Podržava toJson() i fromJson() za secure storage.

#### CertiliaExtendedInfo (lib/src/models/certilia_extended_info.dart)
**Svrha**: Proširene korisničke informacije iz Certilia API-ja

**Polja:**
```dart
class CertiliaExtendedInfo {
  final Map<String, dynamic> rawData;       // Svi podaci kao mapa
  final List<String> availableFields;       // Lista dostupnih polja
  final DateTime? tokenExpiry;              // Token expiry time

  // Dynamic getter
  dynamic getField(String fieldName) => rawData[fieldName];
}
```

**Korištenje:**
```dart
final extendedInfo = await client.getExtendedUserInfo();
print('Available fields: ${extendedInfo.availableFields}');
print('OIB: ${extendedInfo.getField('oib')}');
print('Datum rođenja: ${extendedInfo.getField('date_of_birth')}');
```

---

### 4. Exception Handling

#### CertiliaException (lib/src/exceptions/certilia_exception.dart)
**Hijerarhija:**

```dart
CertiliaException (base)
├── CertiliaAuthenticationException    // Auth errors
├── CertiliaNetworkException           // HTTP errors (ima statusCode)
└── CertiliaConfigurationException     // Config errors
```

**Korištenje:**
```dart
try {
  await certilia.authenticate();
} on CertiliaAuthenticationException catch (e) {
  print('Auth failed: ${e.message}');
} on CertiliaNetworkException catch (e) {
  print('Network error: ${e.message} (HTTP ${e.statusCode})');
} on CertiliaConfigurationException catch (e) {
  print('Config error: ${e.message}');
} catch (e) {
  print('Unknown error: $e');
}
```

---

## 🔄 OAuth 2.0 Flow

### Client-Server Flow (Preporučeno)

```
┌─────────┐                  ┌────────┐                  ┌──────────┐
│ Flutter │                  │ Server │                  │ Certilia │
└────┬────┘                  └───┬────┘                  └────┬─────┘
     │                           │                            │
     │ 1. initialize()           │                            │
     ├──────────────────────────▶│                            │
     │                           │                            │
     │ 2. authenticate()         │                            │
     ├──────────────────────────▶│                            │
     │                           │                            │
     │ 3. GET /initialize        │                            │
     ├──────────────────────────▶│                            │
     │◀──────────────────────────┤                            │
     │   authorization_url,      │                            │
     │   state, session_id       │                            │
     │                           │                            │
     │ 4. Show WebView           │                            │
     │    (authorization_url)    │                            │
     │                           │ 5. OAuth authorize         │
     │                           ├───────────────────────────▶│
     │                           │                            │
     │                           │                User Auth   │
     │                           │                (eOsobna)   │
     │                           │                            │
     │                           │◀───────────────────────────┤
     │                           │   callback with code       │
     │                           │                            │
     │ 6. Detect callback        │                            │
     │    Extract code           │                            │
     │                           │                            │
     │ 7. POST /exchange         │                            │
     │    {code, state,          │                            │
     │     session_id}           │                            │
     ├──────────────────────────▶│                            │
     │                           │ 8. Exchange code           │
     │                           ├───────────────────────────▶│
     │                           │◀───────────────────────────┤
     │◀──────────────────────────┤   tokens                   │
     │   {accessToken,           │                            │
     │    refreshToken,          │                            │
     │    idToken, user}         │                            │
     │                           │                            │
     │ 9. Save tokens            │                            │
     │    (SecureStorage)        │                            │
     │                           │                            │
     │ 10. Return CertiliaUser   │                            │
     │                           │                            │
```

### Token Refresh Flow

```
┌─────────┐                  ┌────────┐                  ┌──────────┐
│ Flutter │                  │ Server │                  │ Certilia │
└────┬────┘                  └───┬────┘                  └────┬─────┘
     │                           │                            │
     │ 1. refreshToken()         │                            │
     ├──────────────────────────▶│                            │
     │                           │                            │
     │ 2. POST /refresh          │                            │
     │    {refresh_token}        │                            │
     │    Authorization: Bearer  │                            │
     ├──────────────────────────▶│                            │
     │                           │ 3. Refresh token           │
     │                           ├───────────────────────────▶│
     │                           │◀───────────────────────────┤
     │◀──────────────────────────┤   new tokens               │
     │   {accessToken,           │                            │
     │    refreshToken,          │                            │
     │    idToken}               │                            │
     │                           │                            │
     │ 4. Update stored tokens   │                            │
     │                           │                            │
```

---

## 🗂️ Backend Server (certilia-server/)

### Svrha
Node.js Express server koji djeluje kao OAuth proxy između Flutter klijenta i Certilia API-ja.

### Ključni Endpointi

#### GET /api/auth/initialize
**Svrha**: Inicijalizira OAuth flow i kreira session

**Query parametri:**
- `response_type`: 'code'
- `redirect_uri`: Server callback URL

**Response:**
```json
{
  "authorization_url": "https://idp.certilia.com/oauth2/authorize?...",
  "state": "random_state_value",
  "session_id": "unique_session_id"
}
```

#### POST /api/auth/exchange
**Svrha**: Zamjenjuje authorization code za tokene

**Request body:**
```json
{
  "code": "authorization_code",
  "state": "state_value",
  "session_id": "session_id"
}
```

**Response:**
```json
{
  "accessToken": "access_token_value",
  "refreshToken": "refresh_token_value",
  "idToken": "id_token_value",
  "expiresIn": 3600,
  "tokenType": "Bearer",
  "user": {
    "sub": "user_id",
    "given_name": "Ime",
    "family_name": "Prezime",
    "email": "email@example.com",
    "oib": "12345678901"
  }
}
```

#### POST /api/auth/refresh
**Svrha**: Osvježava access token

**Headers:**
- `Authorization: Bearer <current_access_token>`

**Request body:**
```json
{
  "refresh_token": "refresh_token_value"
}
```

**Response:** Isti format kao /exchange

#### GET /api/auth/user
**Svrha**: Dohvaća basic user info

**Headers:**
- `Authorization: Bearer <access_token>`

**Response:**
```json
{
  "user": {
    "sub": "user_id",
    "given_name": "Ime",
    "family_name": "Prezime",
    "email": "email@example.com",
    "oib": "12345678901"
  }
}
```

#### GET /api/user/extended-info
**Svrha**: Dohvaća sve dostupne user podatke iz Certilia API-ja

**Headers:**
- `Authorization: Bearer <access_token>`

**Response:**
```json
{
  "availableFields": ["sub", "given_name", "family_name", "oib", "email", "birthdate", ...],
  "sub": "user_id",
  "given_name": "Ime",
  "family_name": "Prezime",
  "oib": "12345678901",
  "email": "email@example.com",
  "birthdate": "1990-01-01",
  "... sve ostale dostupne field-ove ..."
}
```

### Session Management
- Koristi in-memory session storage (production bi trebao koristiti Redis)
- Session timeout: Konfigurabilan
- Session cleanup: Automatski nakon timeout-a

---

## 📱 Example App (example/)

### Glavne Značajke

**Implementacija**: Client-server arhitektura s CertiliaSDKSimple

**UI Features:**
- 🌐 Bilingual support (Hrvatski/English)
- 🔐 Authentication flow demo
- 👤 Basic user info display
- 📋 Extended user info display (dinamički svi field-ovi)
- 🔑 Token display s copy funkcijom
- ⏰ Token expiry countdown
- 🔄 Manual token refresh
- 🚪 Logout funkcionalnost
- 💾 Session persistence demo

**Konfiguracija:**
```dart
_certilia = await CertiliaSDKSimple.initialize(
  clientId: '991dffbb1cdd4d51423e1a5de323f13b15256c63',
  serverUrl: 'https://uniformly-credible-opossum.ngrok-free.app',
  scopes: ['openid', 'profile', 'eid', 'email', 'offline_access'],
  enableLogging: true,
  sessionTimeout: 3600000, // 1 sat
);
```

**State Management:**
- `_certilia`: dynamic - SDK instance
- `_user`: CertiliaUser? - Current user
- `_extendedInfo`: CertiliaExtendedInfo? - Extended info
- `_tokenExpiryTime`: DateTime? - Token expiry
- `_isAuthenticated`: bool - Auth status
- `_isLoading`: bool - Loading state
- `_error`: String? - Error message

**Lifecycle:**
1. `initState()` → `_initializeSDK()`
2. SDK initialization → `_checkAuthStatus()` (nakon 100ms delay)
3. Ako je authenticated → auto-load user i extended info
4. Display UI based on auth state

---

## 🔐 Security Features

### Token Storage
- **FlutterSecureStorage**: Koristi native keychain (iOS) i KeyStore (Android)
- **Encryption**: Tokeni su enkriptirani at-rest
- **Key**: `certilia_token`
- **Format**: JSON serialized CertiliaToken object

### PKCE Support
- **AppAuth implementacija**: Automatski PKCE za iOS/Android
- **Code Verifier**: Random 128-bit vrijednost
- **Code Challenge**: SHA-256 hash verifier-a

### Session Security
- **Ephemeral Sessions**: preferEphemeralSession = true (iOS)
- **Session Isolation**: Svaka auth sesija je izolirana
- **Auto-logout**: Ako token refresh ne uspije

### Network Security
- **HTTPS Only**: Sva komunikacija preko HTTPS-a
- **Timeout Protection**: Request timeouts (10-30s)
- **Retry Logic**: Exponential backoff za failed requests
- **ngrok-skip-browser-warning**: Header za development s ngrok-om

---

## 📊 Dependencies

### Production Dependencies
```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_appauth: ^7.0.0          # Native OAuth za iOS/Android
  http: ^1.2.0                     # HTTP client
  flutter_secure_storage: ^9.2.2  # Secure token storage
  webview_flutter: ^4.8.0          # WebView implementacija
  url_launcher: ^6.2.0             # URL launching
```

### Dev Dependencies
```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^5.0.0            # Linting
  mockito: ^5.4.4                  # Mocking za testove
  build_runner: ^2.4.0             # Code generation
```

---

## 🧪 Testing

### Test Structure
```
test/
├── flutter_certilia_test.dart         # Glavne SDK funkcije
├── certilia_client_test.dart          # Client implementation
├── certilia_client_test.mocks.dart    # Generated mocks
├── utils/
│   └── validators_test.dart           # Validacija funkcije
└── models/
    └── certilia_user_test.dart        # User model testovi
```

### Mock Objects
- **Mockito**: Koristi se za mockanje HTTP client-a, secure storage, itd.
- **Generated Mocks**: `@GenerateMocks([...])` annotations

### Test Coverage
- Unit testovi za sve modele
- Integration testovi za OAuth flow
- Mockani HTTP responses

---

## 📝 Dokumentacija

### Postojeći Dokumenti

#### README.md
- Glavna dokumentacija SDK-a
- Quick start guide
- Platform setup (iOS/Android/Web)
- API reference
- Error handling primjeri
- Troubleshooting

#### SDK_INTEGRATION_PLAN.md
- Plan transformacije u generalizirani SDK
- .env konfiguracija proposal
- Arhitektura i features
- Migration path (4 faze)
- Timeline

#### APPAUTH_MIGRATION.md
- Migracija s WebView na AppAuth
- Security improvements
- Platform configuration
- Code changes
- Troubleshooting

#### certilia-server/CERTILIA_OAUTH_SETUP.md
- OAuth setup za backend server
- Certilia admin portal setup
- Environment variables
- Security best practices

#### certilia-server/DEVELOPMENT.md
- Development setup
- Testing guide
- API documentation
- Deployment guide

---

## 🔮 Roadmap & Budući Razvoj

### Planirane Značajke (iz SDK_INTEGRATION_PLAN.md)

#### Faza 1: Environment Configuration
- [ ] Dodati flutter_dotenv dependency
- [ ] Kreirati environment loader
- [ ] Ažurirati CertiliaConfig za env varijable
- [ ] Dodati .env.example file

#### Faza 2: SDK Wrapper
- [ ] Kreirati CertiliaSDK class
- [ ] Implementirati factory pattern
- [ ] Dodati platform detection
- [ ] Kreirati unified API

#### Faza 3: Dokumentacija
- [ ] Napisati installation guide
- [ ] Kreirati usage examples
- [ ] Dokumentirati sve env varijable
- [ ] Dodati migration guide

#### Faza 4: Testing & Publishing
- [ ] Comprehensive testing
- [ ] Example apps za svaku platformu
- [ ] Publish na pub.dev
- [ ] Kreirati GitHub release

---

## 🚀 Deployment Checklist

### Flutter Client
- [ ] Ažurirati clientId u primjeru
- [ ] Konfigurirati serverUrl za production
- [ ] Postaviti enableLogging = false za production
- [ ] Konfigurirati redirect URLs za sve platforme
- [ ] Testirati na svim target platformama
- [ ] Build production verzije (iOS/Android/Web)

### Backend Server
- [ ] Postaviti production environment varijable
- [ ] Konfigurirati CORS za production domene
- [ ] Implementirati Redis za session storage
- [ ] Postaviti rate limiting
- [ ] Konfigurirati HTTPS
- [ ] Postaviti monitoring i logging
- [ ] Deploy na production server

### Certilia Admin
- [ ] Registrirati OAuth client
- [ ] Konfigurirati redirect URLs
- [ ] Postaviti allowed scopes
- [ ] Konfigurirati token lifetime-ove
- [ ] Testirati OAuth flow

---

## 🐛 Poznati Problemi & Workarounds

### 1. Token Exchange Timeout
**Problem**: Token exchange ponekad timeout-a na sporijem networku

**Workaround**: Implementiran retry logic s 3 pokušaja i exponential backoff

**Kod**: `CertiliaWebViewClient._exchangeCodeForTokens()`

### 2. WebView Auto-Close na Web-u
**Problem**: WebView popup se mora ručno zatvoriti nakon auth-a

**Solution**: Implementiran auto-close s JavaScript-om u web client-u

**Status**: ✅ Riješeno u commit 2b8b3f5

### 3. Token Expiry Detection
**Problem**: Ponekad server vrati expired token bez jasne poruke

**Solution**: Proaktivna provjera token expiry-ja + automatski refresh

**Kod**: `CertiliaWebViewClient.getExtendedUserInfo()` - provjerava status 401/502

### 4. Ngrok Warning Banner
**Problem**: Ngrok pokazuje warning banner u WebView-u

**Solution**: Dodani 'ngrok-skip-browser-warning' headeri u sve requeste

---

## 📞 Support & Kontakt

- **GitHub Issues**: https://github.com/stepanic/flutter_certilia/issues
- **Email**: (dodati ako postoji)
- **Dokumentacija**: Vidi README.md i ostale .md file-ove u projektu

---

## 📄 Licenca

MIT License - Vidi LICENSE file za detalje

---

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

---

## 📚 Dodatne Napomene

### Platform Specifičnosti

#### iOS
- Zahtijeva CFBundleURLTypes u Info.plist
- Podržava ephemeral sessions
- Koristi ASWebAuthenticationSession kroz AppAuth

#### Android
- Zahtijeva RedirectUriReceiverActivity u AndroidManifest.xml
- Minimum SDK: 16
- Koristi Custom Tabs kroz AppAuth

#### Web
- Koristi popup prozore za auth
- Polling mehanizam za completion detection
- Auto-close popup nakon uspjeha

### Best Practices

1. **Uvijek koristite CertiliaSDKSimple** za production
2. **Never hardcode credentials** - koristite environment varijable
3. **Enable logging samo u development-u**
4. **Implementirajte proper error handling** za sve API pozive
5. **Testirajte na svim target platformama** prije deploya
6. **Koristite session persistence** za bolji UX
7. **Implementirajte automatic token refresh** gdje god je moguće

---

**Dokument kreiran**: 2025-09-30
**Verzija SDK-a**: 0.1.0
**Status**: Development / Beta