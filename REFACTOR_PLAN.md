# flutter_certilia — Plan refaktora

**Cilj:** Pretvoriti postojeću `flutter_certilia` biblioteku u čist, reusable "Login with Certilia" SDK temeljen **isključivo na proxy server arhitekturi**, koji se može povući kao dependency u drugu Flutter aplikaciju.

**Datum izrade plana:** 2026-05-12
**Početno stanje:** v0.1.0, ~4165 linija u `lib/src/`, posljednji commit `17bb297` (okt 2025)

---

## Kontekst: što je već isprobano i odbačeno

Git historija pokazuje da postoji **samo jedan stabilan put** za Certilia OAuth na svim platformama: **server-side proxy + WebView (mobile) ili popup+polling (web)**.

| Pristup | Status | Razlog odustanka |
|---|---|---|
| **Native AppAuth** (Custom Tabs / ASWebAuthenticationSession) | Mrtav kod | Certilia prihvaća samo HTTPS redirect URI-je, ne custom URL scheme (`com.app://oauth`). Blokada na strani Certilije. |
| **Manual OAuth + system browser (`url_launcher`)** | Mrtav kod | Isti problem — traži custom URL scheme za povratak. |
| **Direktni OAuth iz Flutter klijenta** | Napušten | Zahtijeva hardkodiranje `client_id`/`client_secret` u aplikaciji; Certilia userinfo endpoint nepouzdan (vidi commiti `1865dbc`, `9184ffd`, `d6c3e32` — sve serverside fallbackovi). |
| **Web popup s `window.postMessage`** | Napušten | Cross-origin policy + Croatian eID flow nepouzdano dostavljao poruke. Zamijenjeno server-side polling-om (`ef67fa4`). |
| **WebView direktno na Certilia (bez proxy-ja)** | Napušten | Android WebView "HTTP client closed", background network problemi, certifikati. Stabilizirano tek kroz proxy. |

**Posljedica:** Sav kod vezan uz prve četiri opcije je mrtav i može se izbrisati bez gubitka funkcionalnosti.

---

## Analiza kvalitete (polazna točka)

Pune ocjene po područjima (vidi pravo memory za detalje):

| Područje | Ocjena | Glavni nalaz |
|---|---|---|
| Arhitektura | D | 4 client klase s copy-pasted OAuth logikom (~1500 lc duplikata) |
| Sigurnost | C- | Nema validacije `state`, ngrok cert bypass u prod kodu, refresh token u headeru |
| Testiranje | F | ~66 linija stvarnih testova, zero coverage za OAuth flow |
| Dependencies | C+ | Min Dart `>=2.19.0` (siječanj 2023, 3+ god star) |
| Docs vs kod | D | CLAUDE.md tvrdi PKCE/session timeout/env config — ništa nije implementirano |

**Ukupna ocjena: D+** — beta, nije production-ready, ali jezgra (proxy + WebView/popup) radi.

---

## Princip refaktora

1. **Inkrementalno** — svaka faza ostavlja aplikaciju u radnom stanju, testirano u Chrome-u prije commita.
2. **Bez novih značajki** — fokus isključivo na kvalitetu i pripremu za reuse. Nikakvi dodatni endpointi ili UI promjene.
3. **Sigurne pobjede prvo** — brisanje mrtvog koda ne mijenja runtime ponašanje, ide prvo.
4. **Cilj svake faze:** smanjenje rizika ili priprema za sljedeću fazu.

---

## Faze

### Faza 0 — Brisanje mrtvog koda (1 dan)

**Cilj:** smanjiti codebase za ~40% uklanjanjem nedohvatljivog koda.

**Akcije:**
- Obriši `lib/src/certilia_appauth_client.dart` (480 lc) — blokirano od Certilije
- Obriši `lib/src/certilia_manual_oauth_client.dart` (652 lc) — isti razlog
- Obriši `lib/src/certilia_sdk.dart` (100 lc) — direktni OAuth, nikad u produkciji
- Obriši `lib/src/certilia_universal_client.dart` (74 lc) — postojao samo za AppAuth/Manual switch
- Obriši `lib/src/certilia_sdk_factory.dart` + `_web.dart` (25 lc)
- Obriši `lib/src/certilia_client.dart` (352 lc) — deprecirano, čekalo v1.0
- Obriši `lib/src/certilia_client_stub.dart` (28 lc) — stub za conditional imports koji više ne postoji
- Obriši `lib/src/models/certilia_config.dart` (186 lc) — zamijenjeno s `CertiliaConfigSimple`
- Obriši obsolete dokumente: `APPAUTH_MIGRATION.md`, `APPAUTH_STATUS.md`, `DEEPLINK_SETUP.md`, `SDK_INTEGRATION_PLAN.md`
- Ažuriraj `lib/flutter_certilia.dart` exporte (ukloni reference na obrisano)
- Ažuriraj `lib/src/certilia_sdk_simple.dart` — ukloni konverziju u puni `CertiliaConfig`, koristi `CertiliaConfigSimple` direktno

**Rezultat:** ~2 klijenta (`CertiliaWebViewClient` mobile/desktop + `CertiliaWebClient` web) + `CertiliaStatefulWrapper` + 4 modela. Public API: jedna klasa + 5 modela.

**Verifikacija:** `flutter run -d chrome` mora raditi identično prije i poslije.

---

### Faza 1 — Konsolidacija (2-3 dana)

**Cilj:** maknuti ~300 lc duplikata između dva preostala klijenta.

**Akcije:**
- Izvuci `ProxyAuthService` (ili mixin) sa zajedničkim metodama:
  - `initializeOAuth() → {authorization_url, state, session_id}`
  - `exchangeCodeForTokens(code, state, sessionId)`
  - `refreshTokens(refreshToken)`
  - `fetchExtendedInfo(accessToken)`
- Verificiraj da oba klijenta koriste postojeći `TokenStorageService` (uveden u `a79f5c7`); ako neki ima vlastiti save/load, ukloni.
- Centraliziraj konstante u `lib/src/constants.dart`:
  - HTTP timeouts (initialize, exchange, refresh)
  - Retry count + backoff bazu
  - Polling interval (web)
  - Popup dimensije (web)
- Preimenuj `CertiliaSDKSimple` → `CertiliaSDK` (jedini ulaz, "Simple" sufiks više nema smisla); zadrži typedef `CertiliaSDKSimple = CertiliaSDK` za 0.x backward-compat.

**Verifikacija:** Chrome auth flow + token refresh + logout — manual test.

---

### Faza 2 — Sigurnost i robusnost (2-3 dana)

**Cilj:** zatvoriti realne rupe pronađene u analizi.

**Akcije:**
1. **Validacija `state` parametra** — klijent mora usporediti `state` u callback URL-u s onim koji je vratio `/initialize`. Trenutno se samo provlači, ne provjerava.
2. **Refresh token u POST body** — sada se šalje u `Authorization: Bearer <refresh_token>` headeru (semantički krivo). Promijeni u oba klijenta. **Napomena:** trebat će uskladiti s `certilia-server` repom — vidi otvoreno pitanje.
3. **Ngrok cert bypass iza `kDebugMode`** — `manual_oauth_client.dart:63-66` (ako preživi Phase 0; vjerojatno bude obrisan). Provjeri da nigdje drugdje nije.
4. **Async init race** — `CertiliaStatefulWrapper` konstruktor zove `_initializeTokens()` bez await-a. Refaktoriraj na lazy-init pattern: čuvaj `_initFuture`, sve public metode `await _initFuture` prije nego što rade bilo što.
5. **`sessionTimeout` enforcement** — ili implementiraj (kompariraj `tokenExpiry` s `now + sessionTimeout`, force-logout iznad praga), ili izbaci iz public API-ja. Trenutno je dead config.
6. **Cleanup timera u dispose-u** — sve `Timer?` varijable u `CertiliaWebClient` moraju biti cancelled u `dispose()` i na error path-evima.

**Verifikacija:** Chrome auth flow, force-refresh, force-logout, kill-and-restart — manual test.

---

### Faza 3 — Testovi (2-3 dana)

**Cilj:** 60%+ line coverage na `lib/src/`, integracija provjerena.

**Akcije:**
- Setup `package:http` `MockClient` za simulaciju proxy servera
- Testovi happy path:
  - `initialize → exchange` vraća tokene
  - `refresh` nakon 401
  - `fetchExtendedInfo` parsing
- Testovi error path:
  - State mismatch → `CertiliaAuthenticationException`
  - Refresh fail → auto-logout
  - Network timeout → retry s backoff
  - Expired token detection
- `TokenStorageService` testovi (save/load/clear)
- Widget test za `CertiliaWebViewClient` minimal — bar dispose lifecycle, ne treba simulirati WebView

**Verifikacija:** `flutter test` zelen, coverage report.

---

### Faza 4 — Priprema za reuse u drugoj aplikaciji (1-2 dana)

**Cilj:** SDK se može povući u drugu app i raditi za 5 minuta.

**Akcije:**
- Bump `pubspec.yaml` na `0.2.0` s breaking changes notom
- Bump min Dart `>=3.2.0`, min Flutter `>=3.16.0` (2026 baseline)
- Zamijeni hardkodirani ngrok URL u `example/lib/main.dart` s `String.fromEnvironment('CERTILIA_SERVER_URL')` + fallback
- **Odluka:** widget `example/lib/certilia_auth/certilia_auth_widget.dart` (369 lc):
  - Opcija A: prebaci u `lib/widgets/certilia_login_button.dart` da bude dio SDK-a
  - Opcija B: ostavi u example/ uz dokumentaciju "copy-paste this"
  - **Default preferiramo A** ako widget nije previše app-specifičan (vidi pri implementaciji)
- Dodaj `CHANGELOG.md` zapis za 0.2.0
- Dodaj sekciju u README: "How to use in your app" s `path:`/`git:` dependency primjerom

**Verifikacija:** nova test Flutter aplikacija povuče SDK kao `git:` dep i renderira login button.

---

### Faza 5 — Dokumentacija (1 dan)

**Cilj:** docs odražavaju kod, ništa lažno ne piše.

**Akcije:**
- Prepiši `README.md`: samo proxy arhitektura, jedan put, jedan primjer
- Prepiši `CLAUDE.md`: ukloni sve tvrdnje o PKCE, AppAuth, env loader-u, polling alternativi
- Dodaj `INTEGRATION.md`: 5 koraka za spajanje nove Flutter aplikacije na `certilia-server`
- Posljednji prelaz: provjeri da svaki link i svaka tvrdnja u docs odgovaraju kodu

---

## Procjena truda

| Faza | Trajanje | Rizik | Vrijednost |
|---|---|---|---|
| 0 — brisanje | 1 dan | Nizak | Visoka (jasnoća) |
| 1 — konsolidacija | 2-3 dana | Srednji | Visoka |
| 2 — sigurnost | 2-3 dana | Srednji | **Kritična** |
| 3 — testovi | 2-3 dana | Nizak | Visoka (reusability) |
| 4 — reuse | 1-2 dana | Nizak | **Kritična** (krajnji cilj) |
| 5 — docs | 1 dan | Nizak | Srednja |

**Ukupno: ~10-13 radnih dana.**

**Kritičan put (MVP za drugu aplikaciju):** Faza 0 → 2 → 4.

---

## Otvorena pitanja

1. **`certilia-server` repo:** Faza 2 zahtijeva i serverside promjene (refresh token u POST body). Trebamo li pristup tom repu paralelno, ili odgodimo te server-strane fix-eve?
2. **Desktop targets:** podržavamo li macOS/Linux/Windows desktop, ili samo iOS+Android+Web? Mijenja WebView strategiju (`webview_flutter` ne radi na desktopu out-of-the-box).
3. **pub.dev publish:** ide li biblioteka na pub.dev ili samo `git:` dependency za internu uporabu? Mijenja koliko striktan moram biti s API stabilnošću i CHANGELOG-om.

---

## Verifikacijski protokol nakon svake faze

Korisnik (Matija) ručno testira u Chrome-u nakon svake inkrementalne izmjene. Standardna sekvenca:

1. `cd example && flutter run -d chrome`
2. Klik "Login with Certilia" → otvara se popup
3. Auth s test eOsobnom → popup se zatvori → user info se prikaže
4. "Refresh token" → traje se sa istim user-om
5. "Logout" → vraća na login ekran
6. Restart app → session persistance OK ili nema, ovisno o stanju
