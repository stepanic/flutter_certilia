# 🚀 Quick Start Guide - Certilia Server

## Za Lokalni Development s Flutter Client-Side App

### 📋 Preduvjeti

- Node.js 18+ instaliran
- ngrok račun i domena (trenutna: `uniformly-credible-opossum.ngrok-free.app`)
- Flutter development environment

---

## ⚡ Brzi Start (1 Naredba)

### Za TEST environment:
```bash
cd certilia-server
./quick-start.sh test
```

### Za PRODUCTION environment:
```bash
cd certilia-server
./quick-start.sh prod
```

Skripta će:
1. ✅ Kreirati `.env` file iz odgovarajućeg templatea
2. ✅ Instalirati dependencies
3. ✅ Kreirati logs direktorij
4. ✅ Ponuditi automatski start servera

---

## 📝 Manualni Start (Korak po Korak)

### 1️⃣ Setup Environment

**Za TEST environment:**
```bash
cp .env.example.test .env
```

**Za PRODUCTION environment:**
```bash
cp .env.example.production .env
```

### 2️⃣ Install Dependencies

```bash
npm install
```

### 3️⃣ Start ngrok (U odvojenom terminalu)

```bash
ngrok http --url=uniformly-credible-opossum.ngrok-free.app 3000
```

**Važno:** Pustite ovaj terminal otvorenim!

### 4️⃣ Start Server

```bash
npm run dev
```

Server će se pokrenuti na `http://localhost:3000`

---

## 🧪 Testiranje Servera

### Test Health Endpoint

```bash
curl https://uniformly-credible-opossum.ngrok-free.app/api/health
```

### Test Kompletan OAuth Flow

```bash
./test-oauth-flow.sh
```

Ova skripta će:
- Inicijalizirati OAuth flow
- Dati vam authorization URL
- Pričekati callback
- Automatski zamijeniti code za tokene
- Testirati authenticated endpoints

### Test Extended User Info

```bash
./test-extended-info.sh <access_token>
```

---

## 🔗 Povezivanje s Flutter Client-Side App

### 1️⃣ Pokreni server (gore opisano)

### 2️⃣ Otvori Flutter projekt

```bash
cd flutter_certilia/example
```

### 3️⃣ Pokreni Flutter app u DEBUG modu

```bash
flutter run
```

**Ili za Web:**
```bash
flutter run -d chrome
```

**Za iOS Simulator:**
```bash
flutter run -d iPhone
```

**Za Android Emulator:**
```bash
flutter run -d emulator
```

### 4️⃣ Flutter App će automatski koristiti server URL

Server URL je u `main.dart`:
```dart
serverUrl: 'https://uniformly-credible-opossum.ngrok-free.app',
```

---

## 📱 Testiranje Complete Flow-a

1. **Pokreni certilia-server:**
   ```bash
   cd certilia-server
   ./quick-start.sh test
   ```

2. **Pokreni ngrok** (u drugom terminalu):
   ```bash
   ngrok http --url=uniformly-credible-opossum.ngrok-free.app 3000
   ```

3. **Pokreni Flutter app** (u trećem terminalu):
   ```bash
   cd flutter_certilia/example
   flutter run
   ```

4. **U Flutter app:**
   - Klikni "Login with eID"
   - Slijedi OAuth flow
   - Provjeri user podatke

---

## 🔄 Prebacivanje između TEST i PROD

### Prebaci server na PROD:
```bash
cp .env.example.production .env
npm run dev
```

### Prebaci server nazad na TEST:
```bash
cp .env.example.test .env
npm run dev
```

---

## 🐛 Troubleshooting

### Server ne odgovara
```bash
# Provjeri je li ngrok pokrenut
curl https://uniformly-credible-opossum.ngrok-free.app/api/health

# Provjeri logs
tail -f logs/certilia-server-test.log
```

### ngrok connection refused
```bash
# Restartaj ngrok
# Provjeri da li server radi na portu 3000
lsof -i :3000
```

### Flutter app ne može spojiti
```dart
// Provjeri serverUrl u Flutter app
// Provjeri CORS u .env:
ALLOWED_ORIGINS=http://localhost:8080,http://localhost:3000,...
```

### OAuth callback error
```bash
# Provjeri Certilia redirect URI postavke:
# Mora biti: https://uniformly-credible-opossum.ngrok-free.app/api/auth/callback
```

---

## 📊 Available Scripts

| Script | Opis |
|--------|------|
| `npm run dev` | Start server s auto-reload |
| `npm start` | Start production server |
| `./quick-start.sh test` | Quick start za TEST env |
| `./quick-start.sh prod` | Quick start za PROD env |
| `./test-oauth-flow.sh` | Test OAuth flow interaktivno |
| `./test-extended-info.sh <token>` | Test extended user info |
| `./start-local.sh test` | Detaljni start za TEST |
| `./start-local.sh prod` | Detaljni start za PROD |

---

## 🌐 Important URLs

| Endpoint | URL |
|----------|-----|
| Health Check | `https://uniformly-credible-opossum.ngrok-free.app/api/health` |
| Initialize Auth | `https://uniformly-credible-opossum.ngrok-free.app/api/auth/initialize` |
| OAuth Callback | `https://uniformly-credible-opossum.ngrok-free.app/api/auth/callback` |
| User Info | `https://uniformly-credible-opossum.ngrok-free.app/api/auth/user` |
| Extended Info | `https://uniformly-credible-opossum.ngrok-free.app/api/user/extended-info` |

---

## 🎯 Tipičan Development Workflow

```bash
# Terminal 1: Start ngrok
ngrok http --url=uniformly-credible-opossum.ngrok-free.app 3000

# Terminal 2: Start server
cd certilia-server
./quick-start.sh test

# Terminal 3: Start Flutter
cd flutter_certilia/example
flutter run

# Test u Flutter app!
```

---

## 📞 Support

Ako nešto ne radi, provjeri:
1. ✅ ngrok je pokrenut i odgovara
2. ✅ Server je pokrenut na portu 3000
3. ✅ .env file postoji i ima ispravne credentials
4. ✅ Certilia redirect URI je postavljen u admin portalu
5. ✅ CORS origins uključuju vašu Flutter app domenu