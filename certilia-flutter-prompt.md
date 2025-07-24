# Implementacija flutter_certilia Flutter paketa

## Kontekst i cilj

Trebaš implementirati Flutter paket za Certilia Identity API integraciju. Certilia je hrvatski servis za autentifikaciju i verifikaciju identiteta koji koristi OAuth 2.0 protokol i podržava prijavu putem hrvatskih elektroničkih osobnih iskaznica (eOsobna) preko NIAS sustava.

Paket će biti open source na GitHub-u (https://github.com/stepanic/flutter_certilia) i objavljen na pub.dev.

## Tehnički zahtjevi

1. **OAuth 2.0 implementacija** koristeći `flutter_appauth` paket
2. **PKCE (Proof Key for Code Exchange)** podrška za sigurniju autentifikaciju
3. **Null safety** - obavezno
4. **Platforma podrška**: iOS, Android, Web
5. **Minimalna SDK verzija**: Dart >=2.19.0, Flutter >=3.0.0

## Certilia API specifikacije

Certilia koristi standardni OAuth 2.0 flow sa sljedećim endpoint-ovima:
- Authorization endpoint: `https://login.certilia.com/oauth/authorize`
- Token endpoint: `https://login.certilia.com/oauth/token`
- User info endpoint: `https://login.certilia.com/oauth/userinfo`

Podržani scope-ovi:
- `openid` - osnovni OpenID Connect
- `profile` - pristup korisničkim podacima
- `eid` - pristup eID podacima

## Struktura paketa

```
flutter_certilia/
├── lib/
│   ├── flutter_certilia.dart
│   └── src/
│       ├── certilia_client.dart
│       ├── models/
│       │   ├── certilia_user.dart
│       │   ├── certilia_config.dart
│       │   └── certilia_token.dart
│       ├── exceptions/
│       │   └── certilia_exception.dart
│       ├── constants.dart
│       └── utils/
│           └── validators.dart
├── test/
│   ├── certilia_client_test.dart
│   ├── models/
│   │   └── certilia_user_test.dart
│   └── utils/
│       └── validators_test.dart
├── example/
│   ├── lib/
│   │   └── main.dart
│   ├── pubspec.yaml
│   └── README.md
├── CHANGELOG.md
├── LICENSE
├── README.md
└── pubspec.yaml
```

## Implementacijski zahtjevi

### 1. `lib/flutter_certilia.dart`
Export file koji eksportira sve javne klase:
```dart
export 'src/certilia_client.dart';
export 'src/models/certilia_user.dart';
export 'src/models/certilia_config.dart';
export 'src/exceptions/certilia_exception.dart';
```

### 2. `lib/src/models/certilia_config.dart`
Model za konfiguraciju:
- `clientId` (required)
- `redirectUrl` (required)
- `scopes` (default: ['openid', 'profile', 'eid'])
- `discoveryUrl` (optional, za auto-discovery)
- `preferEphemeralSession` (default: true za iOS)

### 3. `lib/src/models/certilia_user.dart`
Model za korisničke podatke:
- `sub` - jedinstveni identifikator
- `firstName` - ime
- `lastName` - prezime
- `oib` - OIB (hrvatski porezni broj)
- `dateOfBirth` - datum rođenja
- `email` - email (ako je dostupan)
- `raw` - sirovi JSON response

Implementiraj `fromJson`, `toJson`, `copyWith` metode.

### 4. `lib/src/models/certilia_token.dart`
Model za token podatke:
- `accessToken`
- `refreshToken`
- `idToken`
- `expiresAt`
- `tokenType`

### 5. `lib/src/certilia_client.dart`
Glavna klasa sa sljedećim metodama:

```dart
class CertiliaClient {
  // Konstruktor
  CertiliaClient({required CertiliaConfig config});
  
  // Autentifikacija
  Future<CertiliaUser> authenticate();
  
  // Provjera je li korisnik prijavljen
  bool get isAuthenticated;
  
  // Dohvati trenutnog korisnika
  Future<CertiliaUser?> getCurrentUser();
  
  // Refresh token
  Future<void> refreshToken();
  
  // Logout
  Future<void> logout();
  
  // End session
  Future<void> endSession();
}
```

### 6. `lib/src/exceptions/certilia_exception.dart`
Custom exception klase:
- `CertiliaException` - bazna klasa
- `CertiliaAuthenticationException`
- `CertiliaNetworkException`
- `CertiliaConfigurationException`

### 7. `lib/src/constants.dart`
Konstante za Certilia endpoint-ove i default vrijednosti.

### 8. `example/lib/main.dart`
Kompletan primjer aplikacije koji demonstrira:
- Inicijalizaciju
- Login button
- Prikaz korisničkih podataka nakon prijave
- Logout funkcionalnost
- Error handling

## Best practices koje moraš slijediti

1. **Dokumentacija**: Svaka javna metoda i klasa mora imati dartdoc komentare
2. **Error handling**: Svi network pozivi moraju imati try-catch blokove
3. **Null safety**: Striktno poštuj null safety pravila
4. **Testovi**: Napiši unit testove za sve modele i glavne funkcionalnosti
5. **Linting**: Kod mora proći `flutter analyze` bez grešaka
6. **Formatting**: Koristi `dart format`

## README.md sadržaj

README mora sadržavati:
1. Badges (pub version, license)
2. Kratak opis na engleskom i hrvatskom
3. Features listu
4. Instalacijske instrukcije
5. Primjer korištenja
6. Konfiguraciju za iOS i Android
7. Troubleshooting sekciju
8. Licencu (MIT)

## iOS specifična konfiguracija

U example/ios/Runner/Info.plist dodaj:
```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>com.example.app</string>
        </array>
    </dict>
</array>
```

## Android specifična konfiguracija

U example/android/app/build.gradle dodaj manifestPlaceholders za redirect URL.

## Dodatni zahtjevi

1. Implementiraj PKCE flow za dodatnu sigurnost
2. Podrži custom User-Agent string
3. Omogući debugiranje s opcijskim logging-om
4. Implementiraj token persistenciju (optional)
5. Dodaj podršku za biometric authentication (za buduće verzije)

## Testiranje

1. Napiši unit testove za sve modele
2. Napiši mock testove za CertiliaClient
3. Pokrij edge case-ove (network errors, invalid tokens, etc.)

Započni implementaciju s osnovnim modelima, zatim implementiraj CertiliaClient klasu, i na kraju napravi example aplikaciju. Sav kod mora biti profesionalan, dobro dokumentiran i slijediti Flutter/Dart best practices.