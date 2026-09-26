# flutter_certilia: onboarding za Claude

Sažet pregled stvarnog stanja koda za buduće sesije rada na ovom repu.

**Verzija:** 0.2.0 · **Datum posljednjeg refaktora:** svibanj 2026 ·
**Licenca:** MIT

## Što ovo radi

Flutter SDK za prijavu hrvatskom elektroničkom osobnom iskaznicom
(eOsobna) preko Certilije / NIAS-a. Normalno komunicira s backend
proxyjem (`certilia-server/` u istom repu) koji drži OAuth credentialse
i razgovara s Certilia IDP-om; u direct modu (`CertiliaDirectClient`)
aplikacija sama drži klijenta i razgovara izravno s Certilijom.

```mermaid
flowchart LR
    A[Flutter app<br/>flutter_certilia SDK] <--> B[certilia-server<br/>Node.js proxy]
    B <--> C[Certilia IDP]
```

## Što je provjereno o Certiliji (2026-09-26)

Provjereno pravim eID loginima i izravnim pozivima na `idp.certilia.com`
(WSO2 Identity Server):

1. **Code exchange traži client secret.** Certilia izdaje samo
   povjerljive (confidential) klijente: token endpoint bez secreta vraća
   `invalid_client` ("Unsupported Client Authentication Method!"), a
   developer portal ne nudi javni PKCE klijent. Secret drži ili
   `certilia-server`, ili sama aplikacija u direct modu
   (`CertiliaDirectClient`): token endpoint i JWKS dopuštaju
   cross-origin pozive, pa login radi i bez ikakvog servera. U direct
   modu secret je javan; štite exact-match callback i PKCE, zato direct
   mode traži https callback. Implicit (`response_type=id_token`) je za
   portal klijente isključen (`unauthorized_client`).
2. **Jedan callback URL po klijentu, točno podudaranje.** Svaki tok s
   vlastitim callbackom treba vlastiti Certilia klijent; proxy ih bira
   po `redirect_uri` (`CERTILIA_CLIENTS`).
3. **Custom scheme radi na IDP-u, portal ga formalno ne dopušta.**
   Portal piše "Only HTTPS is allowed" i odbija `scheme://...`, ali
   prihvaća `hr.example.app:1/callback` (valjan URI sa shemom
   `hr.example.app`) zbog buga u regexu. IDP ga poštuje: login, exchange
   i refresh rade. Preferiraj https App Link / Universal Link.
4. **`userinfo` nije nepouzdan nego vezan za browser.** Access token je
   vezan za `atbv` cookie koji Certilia postavi u browseru pri loginu;
   poziv sa servera uvijek dobije "Valid token binding value not
   present". Claimove čitamo iz ID tokena (`claims` parametar traži OIB).
5. **`window.opener.postMessage` ne radi pod COOP-om.** Kad app šalje
   `Cross-Origin-Opener-Policy: same-origin`, popup na Certiliji ima
   `window.opener === null`. Callback stranica na originu aplikacije
   zato javlja rezultat preko BroadcastChannela i localStoragea.
6. **Safari (i svi browseri na iOS-u) blokira `window.open` nakon
   mrežnog awaita.** Web klijent otvara prazan popup prije poziva
   proxyju; `authenticate()` se mora zvati izravno iz tap handlera.
7. **Login potvrđuje push u Certilia aplikaciji**, pa WebView, Auth Tab,
   ASWebAuthenticationSession i popup rade jednako. Stranica na mobitelu
   nudi i gumb za otvaranje Certilia aplikacije (prebacivanje između
   aplikacija), ali push radi i bez njega. U Safariju na iOS-u gumb
   otvara Certilia aplikaciju (testirano). In-app WebView
   (`webview_flutter`) takve linkove po defaultu ne predaje drugim
   aplikacijama, pa gumb tamo vjerojatno završi greškom (netestirano).
8. **Android: bez `preferEphemeral`.** S njim flutter_web_auth_2 5.x na
   Chromeu < 141 otvara običan Custom Tab koji nakon redirecta ostaje
   iznad aplikacije. `CertiliaBrowserClient` ga šalje samo na iOS-u.
   Provjereno na Android 16 emulatoru (Chrome 133) pravim loginom i
   lažnim proxyjem.
9. **Refresh kod Certilije ne radi** za portal klijente
   (`invalid_grant`, "Persisted access token data not found"), ni sa
   servera ni iz browsera. `/api/auth/refresh` proxyja samo ponovno
   potpisuje svoj JWT i Certiliju ne zove.
10. **Login se gubi ako aplikacija umre usred logina.** Započeti login
    (PKCE verifier, state, nonce; u proxy modu session_id) postoji samo
    u memoriji. Ako Android ubije aplikaciju dok korisnik potvrđuje push
    u Certilia aplikaciji, redirect stiže u novi proces i flutter_web_auth_2
    ga odbacuje. Popravak: hvatati redirect intent pri hladnom startu
    (npr. `app_links`) i čuvati započeti login u secure storageu. Nije
    reproducirano; "Don't keep activities" u developer opcijama to omogućuje.
11. **Code se vraća samo u browser koji se prijavio.** Na webu ga
    donosi callback stranica na originu aplikacije. Ne dodaj put kojim
    code ide drugamo (npr. proxy endpoint koji aplikacija pollira):
    dobio bi ga onaj tko pollira, pa i netko tko je sam pokrenuo login i
    korisniku poslao Certilia link da pokupi njegov code. Zato web traži
    `callbackUrl`, proxy nema polling endpointe, a callback stranica
    proxyja code ne šalje `window.opener`u.

`REFACTOR_PLAN.md` uz izvornu listu odbačenih pristupa ima tablicu s
provjerenim razlozima.

## Layout

```
lib/
  flutter_certilia.dart                    # javni exports (jedan entry point)
  src/
    certilia_sdk.dart                      # CertiliaSDK.initialize()
    certilia_sdk_factory.dart              # stub (mobile)
    certilia_sdk_factory_web.dart          # web platform factory
    certilia_native_client.dart            # mobile/desktop: zajednički OAuth tok (exchange, refresh, state)
    certilia_webview_client.dart           # mobile/desktop: WebView flow (bez callbackUrl)
    certilia_browser_client.dart           # mobile: sistemski browser (callbackUrl: custom scheme / App Link)
    certilia_web_client.dart               # web: popup + callback stranica
    oauth_callback.dart                    # parsiranje callback URL-a, provjera state-a
    refresh_errors.dart                    # koji neuspjeli refresh završava sesiju
    certilia_stateful_wrapper.dart         # mobile/desktop: state management
    services/
      certilia_auth_backend.dart           # sučelje: initialize/exchange/refresh/profil
      auth_backend_factory.dart            # proxy ili direct prema konfiguraciji
      proxy_auth_service.dart              # **sve** HTTP komunikacije s proxyjem
      direct_auth_service.dart             # direct mode: Certilia izravno, PKCE, provjera ID tokena
      token_storage_service.dart           # FlutterSecureStorage wrapper
      certilia_logger.dart                 # logging
    models/
      certilia_config.dart                 # konfiguracija
      certilia_direct_client.dart          # client id/secret za direct mode
      certilia_user.dart                   # osnovni profil
      certilia_token.dart                  # access/refresh/ID tokeni
      certilia_extended_info.dart          # puni profil
    exceptions/
      certilia_exception.dart              # hijerarhija iznimaka
example/                                   # demo aplikacija, copy-paste-ready UI
certilia-server/                           # Node.js proxy
test/                                      # unit testovi (93 prolaze)
```

## Javni API

Jedini entry point:

```dart
final certilia = await CertiliaSDK.initialize(serverUrl: '...');
// ili, bez servera:
final certilia = await CertiliaSDK.initialize(
  direct: const CertiliaDirectClient(clientId: '...', clientSecret: '...'),
  callbackUrl: 'https://app.example/certilia_callback.html',
);
```

`callbackUrl` bira kamo Certilia vraća browser nakon logina (vidi README,
"Login flows"). Na webu je obavezan; na mobitelu bez njega vrijedi
in-app WebView.

Vraćeni objekt ima različit konkretan tip ovisno o platformi
(`CertiliaWebClient` na webu, `CertiliaStatefulWrapper` na mobile/
desktopu), ali metode su iste:

- `authenticate(context) → CertiliaUser`
- `checkAuthenticationStatus() → bool`
- `getCurrentUser() → CertiliaUser?`
- `refreshToken()`
- `getExtendedUserInfo() → CertiliaExtendedInfo?`
- `logout()`

Izvezeni modeli: `CertiliaConfig`, `CertiliaDirectClient`,
`CertiliaUser`, `CertiliaToken`, `CertiliaExtendedInfo`. Iznimke: `CertiliaException`,
`CertiliaAuthenticationException`, `CertiliaNetworkException`,
`CertiliaConfigurationException`. Deprecated typedef-ovi:
`CertiliaSDKSimple = CertiliaSDK`, `CertiliaConfigSimple = CertiliaConfig`.

## Interna arhitektura

```mermaid
flowchart TD
    SDK[CertiliaSDK.initialize] --> F{Platform?}
    F -->|web| WC[CertiliaWebClient]
    F -->|mobile/desktop| SW[CertiliaStatefulWrapper]
    SW -->|bez callbackUrl| WV[CertiliaWebViewClient]
    SW -->|callbackUrl| BC[CertiliaBrowserClient]
    WC --> B{CertiliaAuthBackend}
    WV --> B
    BC --> B
    B -->|proxy mode| PAS[ProxyAuthService]
    B -->|direct mode| DAS[DirectAuthService]
    WC --> TSS[TokenStorageService]
    SW --> TSS
    PAS -->|HTTP| Proxy[(certilia-server)]
    DAS -->|HTTP| IDP[(Certilia IDP)]
    TSS -->|secure storage| Native[(keychain / KeyStore)]
```

`CertiliaSDK.initialize` bira klijenta po platformi, a
`createAuthBackend` bira backend: `DirectAuthService` kad je zadan
`direct`, inače `ProxyAuthService`. Klijenti samo prikazuju Certilijinu
stranicu (WebView, sistemski browser ili popup) i vraćaju callback;
HTTP pozive radi backend, a tokene sprema `TokenStorageService`.

## Tok podataka

Tokovi su opisani za proxy mode. U direct modu `DirectAuthService` sam
napravi korake initialize i exchange (PKCE, poziv token endpointa,
provjera ID tokena), bez servera; direct mode uvijek ima `callbackUrl`.

### Mobile / desktop (WebView)

1. `CertiliaStatefulWrapper.authenticate(context)` →
2. `CertiliaWebViewClient.authenticate(context)` →
3. `ProxyAuthService.initialize()` → server vraća authorization_url,
   state, session_id
4. WebView pokrene authorization_url; user autenticira preko Certilije
5. WebView prepozna callback URL proxyja (`$serverUrl/api/auth/callback`)
   i vrati ga; `codeFromCallback` provjeri `state` i izvuče `code`
6. `ProxyAuthService.exchange(code, state, sessionId)` → tokeni
7. `CertiliaStatefulWrapper` sprema tokene + user u secure storage

### Mobile (sistemski browser, `callbackUrl` postavljen)

1. `CertiliaBrowserClient.authenticate(context)` →
2. `ProxyAuthService.initialize(redirectUri: callbackUrl)`; proxy bira
   Certilia klijenta registriranog za taj callback
3. `flutter_web_auth_2` otvara authorization_url u Auth Tabu / Custom
   Tabu (Android) ili `ASWebAuthenticationSession` (iOS)
4. OS vraća redirect na custom scheme ili App Link; `codeFromCallback`
   provjeri `state` i izvuče `code`
5. `ProxyAuthService.exchange(...)` → tokeni

### Web (popup + callback stranica)

1. `CertiliaWebClient.authenticate(context)` otvara prazan popup
   odmah, prije ikakvog awaita (Safari)
2. `ProxyAuthService.initialize(redirectUri: callbackUrl)`
3. Popup ide na authorization_url; Certilia ga vraća na
   `certilia_callback.html` na originu aplikacije
4. Stranica šalje callback URL preko BroadcastChannela `certilia_auth`
   i ostavlja ga u localStorageu (`certilia_auth_result`); app ga čita
   i briše, provjeri `state`
5. `ProxyAuthService.exchange(...)` → tokeni

## Endpointi `certilia-server`-a koje SDK koristi

| HTTP | Path | Što radi |
|---|---|---|
| GET | `/api/auth/initialize` | Pokreće OAuth, vraća authorization_url + state + session_id |
| GET | `/api/auth/callback` | Callback proxyja za mobilni WebView flow (Certilia ga zove) |
| POST | `/api/auth/exchange` | Code → tokeni |
| POST | `/api/auth/refresh` | Refresh tokena (oba tokena u body-ju) |
| GET | `/api/auth/user` | Basic user info iz JWT-a |
| GET | `/api/user/extended-info` | Puni profil iz Certilije |

## Konvencije

- Sve HTTP komunikacije idu kroz `CertiliaAuthBackend`
  (`ProxyAuthService` ili `DirectAuthService`). Ne dodaj direktan
  `http.get/post` u klijente: takav poziv zaobilazi retry, timeout i
  obradu grešaka iz backenda.
- Tokene sprema i čita samo `TokenStorageService`. Ne pristupaj
  `FlutterSecureStorage` direktno, da svi čitaju i pišu iste ključeve.
- Sva logiranja kroz `CertiliaLogger`, koji ispisuje samo kad je
  `config.enableLogging` uključen.
- Na webu se **ne** šalju custom HTTP headeri: CORS konfiguracija
  servera dopušta samo `Content-Type` i `Authorization`, pa bi preflight
  za bilo koji drugi header pao. Vidi `ProxyAuthService._baseHeaders`.
- Konstruktori `CertiliaWebClient` i `CertiliaStatefulWrapper`
  pokreću `_initializeTokens()/_initializeState()` u `_ready` future.
  Sve async public metode počinju s `await _ready;`. Nemoj to ukloniti:
  bez toga metoda pozvana odmah nakon konstrukcije (npr. nakon hot
  restarta) ne vidi spremljene tokene.
- Refresh flow šalje oba tokena u JSON body, ne u Authorization header.
  Server (`authController.refreshToken`) prihvaća i header, zbog
  starijih klijenata; novi kod ga ne koristi.

## Razvojni protokol

- **Ručna provjera u Chromeu** nakon svake izmjene: korisnik pokrene
  `flutter run -d chrome` i prođe login.
- **Server pokreni paralelno** s `npm run dev:prod` u
  `certilia-server/`. Mora postojati ngrok tunel za auth callback na
  javnoj HTTPS adresi.
- **Testovi:** `flutter test` mora biti zelen prije svakog commita.
  Trenutno 93 testa; ako mijenjaš `ProxyAuthService`, ažuriraj
  `test/services/proxy_auth_service_test.dart`.
- **Commit poruke:** conventional (`feat:`, `fix:`, `refactor:`,
  `docs:`, `test:`, `build:`). Engleski. Kratak naslov, body objašnjava
  **zašto** ne samo što.
- **Sigurne stvari raditi slobodno:** edit, test, lokalni commit.
- **Pitati prije:** push, force push, brisanje grana, mijenjanje
  shared infrastrukture, mijenjanje server endpointa (deploy se
  pokvari ako klijent i server ne očekuju iste endpointe).

## Što se s ovim namjerava raditi

Glavni cilj refaktora bio je pripremiti SDK za reuse kao "Login with
Certilia" komponenta u drugoj Flutter aplikaciji. Vidi
`REFACTOR_PLAN.md` za fazni plan i postignuto stanje.

Konkretno: druga aplikacija uključi ovaj repo kao `git:` dependency,
spoji se na isti `certilia-server` proxy, pozove `CertiliaSDK.initialize()`
i po potrebi kopira UI iz `example/lib/certilia_auth/` kao početak.
