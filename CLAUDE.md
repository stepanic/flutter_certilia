# flutter_certilia — onboarding za Claude

Sažet referent za buduće sesije rada na ovom repu. Ne aspiracije —
samo stvarno stanje koda.

**Verzija:** 0.2.0 · **Datum posljednjeg refaktora:** svibanj 2026 ·
**Licenca:** MIT

## Što ovo radi

Flutter SDK za prijavu hrvatskom elektroničkom osobnom iskaznicom
(eOsobna) preko Certilije / NIAS-a. Komunicira **isključivo** s
backend proxyjem (`certilia-server/` u istom repu); proxy drži OAuth
credentialse i razgovara s Certilia IDP-om.

```
Flutter (this SDK) ⇄ certilia-server (Node.js) ⇄ Certilia IDP
```

## Što NE smije biti predloženo

Ovo su pristupi koji su isprobani i institucionalno/tehnički blokirani.
Detalji u `REFACTOR_PLAN.md` i memory file-u `project-abandoned-approaches`:

1. **Native AppAuth (custom URL scheme)** — Certilia ne registrira
   `com.example.app://oauth`. Blokada na strani providera.
2. **Direktni OAuth iz Flutter klijenta** — zahtijeva client_id /
   secret u aplikaciji; Certilia `userinfo` endpoint nepouzdan u
   produkciji.
3. **Web popup s `window.postMessage`** — cross-origin policy +
   eID flow nepouzdano dostavlja poruke. Zato server-side polling.
4. **WebView direktno na Certilia (bez proxyja)** — Android/iOS
   WebView issues s background networkom i certifikatima.

Ako se javi prijedlog u bilo kojem od ova četiri smjera, pogledaj git
historiju za commit u kojem je odbačen prije nego što ga implementiraš.

## Layout

```
lib/
  flutter_certilia.dart                    # javni exports (jedan entry point)
  src/
    certilia_sdk.dart                      # CertiliaSDK.initialize()
    certilia_sdk_factory.dart              # stub (mobile)
    certilia_sdk_factory_web.dart          # web platform factory
    certilia_webview_client.dart           # mobile/desktop: WebView flow
    certilia_web_client.dart               # web: popup + polling flow
    certilia_stateful_wrapper.dart         # mobile/desktop: state management
    services/
      proxy_auth_service.dart              # **sve** HTTP komunikacije s proxyjem
      token_storage_service.dart           # FlutterSecureStorage wrapper
      certilia_logger.dart                 # logging
    models/
      certilia_config.dart                 # konfiguracija
      certilia_user.dart                   # osnovni profil
      certilia_token.dart                  # access/refresh/ID tokeni
      certilia_extended_info.dart          # puni profil
    exceptions/
      certilia_exception.dart              # hijerarhija iznimaka
example/                                   # demo aplikacija — copy-paste-ready UI
certilia-server/                           # Node.js proxy
test/                                      # unit testovi (46 prolaze)
```

## Javni API

Jedini entry point:

```dart
final certilia = await CertiliaSDK.initialize(serverUrl: '...');
```

Vraćeni objekt ima različit konkretan tip ovisno o platformi
(`CertiliaWebClient` na webu, `CertiliaStatefulWrapper` na mobile/
desktopu), ali metode su iste:

- `authenticate(context) → CertiliaUser`
- `checkAuthenticationStatus() → bool`
- `getCurrentUser() → CertiliaUser?`
- `refreshToken() / refreshToken({accessToken, refreshToken})` (varijanta po klijentu)
- `getExtendedUserInfo() → CertiliaExtendedInfo?`
- `logout()`

Modeli izvezeni: `CertiliaConfig`, `CertiliaUser`, `CertiliaToken`,
`CertiliaExtendedInfo`. Iznimke: `CertiliaException`,
`CertiliaAuthenticationException`, `CertiliaNetworkException`,
`CertiliaConfigurationException`. Deprecated typedef-ovi:
`CertiliaSDKSimple = CertiliaSDK`, `CertiliaConfigSimple = CertiliaConfig`.

## Tok podataka

### Mobile / desktop (WebView)

1. `CertiliaStatefulWrapper.authenticate(context)` →
2. `CertiliaWebViewClient.authenticate(context)` →
3. `ProxyAuthService.initialize()` → server vraća authorization_url,
   state, session_id
4. WebView pokrene authorization_url; user autenticira preko Certilije
5. WebView detektira callback (`$serverUrl/api/auth/callback`),
   validira `state`, izvuče `code`
6. `ProxyAuthService.exchange(code, state, sessionId)` → tokeni
7. `CertiliaStatefulWrapper` sprema tokene + user u secure storage

### Web (popup + polling)

1. `CertiliaWebClient.authenticate(context)` →
2. `ProxyAuthService.initialize()` → state + session_id
3. `ProxyAuthService.startPollingSession()` → polling_id
4. Otvori popup na authorization_url
5. Server obradi callback, sprema rezultat na polling_id
6. Klijent svake 2s `ProxyAuthService.pollStatus(pollingId)` →
   čim status=completed, dohvati code
7. `ProxyAuthService.exchange(code, ...)` → tokeni
8. Popup se sam zatvori

## Endpointi `certilia-server`-a koje SDK koristi

| HTTP | Path | Što radi |
|---|---|---|
| GET | `/api/auth/initialize` | Pokreće OAuth, vraća authorization_url + state + session_id |
| GET | `/api/auth/callback` | Server-side callback (Certilia ga zove) |
| POST | `/api/auth/exchange` | Code → tokeni |
| POST | `/api/auth/refresh` | Refresh tokena (oba tokena u body-ju) |
| POST | `/api/auth/polling/start` | Web: kreira polling sesiju |
| GET | `/api/auth/polling/:id/status` | Web: polling result |
| GET | `/api/auth/user` | Basic user info iz JWT-a |
| GET | `/api/user/extended-info` | Puni profil iz Certilije |

## Konvencije

- Sve HTTP komunikacije idu kroz `ProxyAuthService`. Ne dodaj direktan
  `http.get/post` u klijente — zaobilazi retry/timeout/error policy.
- Sva token persistencija ide kroz `TokenStorageService`. Ne pristupaj
  `FlutterSecureStorage` direktno (cache key konzistentnost).
- Sva logiranja kroz `CertiliaLogger` — gated na `config.enableLogging`.
- Custom HTTP headeri se **ne** šalju na webu — trigaju CORS preflight
  koji server ne dozvoljava. Vidi komentar u
  `ProxyAuthService._baseHeaders`.
- Konstruktori `CertiliaWebClient` i `CertiliaStatefulWrapper`
  pokreću `_initializeTokens()/_initializeState()` u `_ready` future.
  Sve async public metode počinju s `await _ready;` — nemoj to ukloniti
  (race koji se vraćao na svaki hot restart).
- Refresh flow šalje oba tokena u JSON body, ne u Authorization header.
  Server (`authController.refreshToken`) fallback prihvaća header za
  backward compat — nemoj se osloniti na to za nove klijente.

## Razvojni protokol

- **Manualna Chrome verifikacija** nakon svake inkrementalne izmjene
  (vidi memory: `feedback-chrome-verify`). User radi `flutter run -d
  chrome` i prolazi auth flow.
- **Server pokreni paralelno** s `npm run dev:prod` u
  `certilia-server/`. Mora postojati ngrok tunel za auth callback na
  javnoj HTTPS adresi.
- **Testovi:** `flutter test` mora biti zelen prije svakog commita.
  Trenutno 46 testova; ako mijenjaš `ProxyAuthService`, ažuriraj
  `test/services/proxy_auth_service_test.dart`.
- **Commit poruke:** conventional (`feat:`, `fix:`, `refactor:`,
  `docs:`, `test:`, `build:`). Engleski. Kratak naslov, body objašnjava
  **zašto** ne samo što.
- **Sigurne stvari raditi slobodno:** edit, test, lokalni commit.
- **Pitati prije:** push, force push, brisanje grana, mijenjanje
  shared infrastrukture, mijenjanje server endpointa (može pucati
  deploy ako client/server idu out-of-sync).

## Što se s ovim namjerava raditi

Glavni cilj refaktora bio je pripremiti SDK za reuse kao "Login with
Certilia" komponenta u drugoj Flutter aplikaciji. Vidi
`REFACTOR_PLAN.md` za fazni plan i postignuto stanje.

Konkretno: druga aplikacija pulla ovaj repo kao `git:` dep, povezuje
se na isti `certilia-server` proxy, koristi `CertiliaSDK.initialize()`
i copy-paste-a UI iz `example/lib/certilia_auth/` ako treba početni
template.
