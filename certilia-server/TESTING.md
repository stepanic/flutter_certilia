# 🧪 Testing Guide - Certilia Server

## 📋 Available Test Scripts

### 1️⃣ **test-oauth-flow.sh**
Kompletan end-to-end OAuth flow test za trenutni environment.

```bash
./test-oauth-flow.sh
```

**Što radi:**
- Inicijalizira OAuth flow
- Daje authorization URL
- Čeka callback
- Zamjenjuje code za tokens
- Testira user endpoint

---

### 2️⃣ **test-extended-info.sh**
Test extended user info endpointa.

```bash
./test-extended-info.sh <access_token>
```

**Što radi:**
- Poziva `/api/user/extended-info`
- Prikazuje sve dostupne fieldove
- Prikazuje user info

---

### 3️⃣ **test-both-environments.sh** 🆕
Testira oba environmenta (TEST i PROD) i uspoređuje rezultate.

```bash
./test-both-environments.sh
```

**Što radi:**
- Detektira trenutni environment
- Pita koji environment testirati (TEST/PROD/Both)
- Izvršava kompletan OAuth flow
- Uspoređuje extended info između environmenta
- Pokazuje razlike ako postoje

---

### 4️⃣ **compare-extended-info.sh** 🆕
Brza usporedba extended info za oba environmenta (trebaju vam access tokeni).

```bash
./compare-extended-info.sh
```

**Što radi:**
- Traži access tokene za oba environmenta
- Poziva `/api/user/extended-info` za oba
- Uspoređuje available fields
- Prikazuje razlike

---

## 🎯 Preporučeni Testing Workflow

### Za testiranje jednog environmenta:

**Terminal 1 - NGROK:**
```bash
ngrok http --url=uniformly-credible-opossum.ngrok-free.app 3000
```

**Terminal 2 - SERVER (TEST):**
```bash
npm run dev:test
```

**Terminal 3 - TEST:**
```bash
./test-oauth-flow.sh
```

---

### Za usporedbu TEST vs PROD:

#### Opcija A: Automatski (preporučeno)

**Terminal 1 - NGROK:**
```bash
ngrok http --url=uniformly-credible-opossum.ngrok-free.app 3000
```

**Terminal 2 - SERVER:**
```bash
# Start s TEST
npm run dev:test
```

**Terminal 3 - TEST:**
```bash
./test-both-environments.sh
# Odaberi opciju 3 (Both)
# Slijedi upute za testiranje TEST-a
# Kad završi, restartaj server s: npm run dev:prod
# Nastavi s testiranjem PROD-a
```

---

#### Opcija B: Manualno (s access tokenima)

**1. Test TEST environment:**
```bash
# Terminal 2
npm run dev:test

# Terminal 3
./test-oauth-flow.sh
# Kopiraj accessToken
```

**2. Test PROD environment:**
```bash
# Terminal 2 (Ctrl+C pa)
npm run dev:prod

# Terminal 3
./test-oauth-flow.sh
# Kopiraj accessToken
```

**3. Usporedi:**
```bash
./compare-extended-info.sh
# Zalijepi oba access tokena kada pita
```

---

## 🔍 Što Provjeriti

### 1. Basic Auth Flow
```bash
./test-oauth-flow.sh
```

**Provjeri:**
- ✅ Authorization URL koristi ispravan Certilia endpoint
  - TEST: `https://idp.test.certilia.com/oauth2/authorize`
  - PROD: `https://idp.certilia.com/oauth2/authorize`
- ✅ Token exchange uspješan
- ✅ User data vraćeni

### 2. Extended User Info
```bash
./test-extended-info.sh <access_token>
```

**Provjeri:**
- ✅ Endpoint odgovara (status 200)
- ✅ `availableFields` array postoji
- ✅ `userInfo` objekt postoji
- ✅ Svi fieldovi su u response-u

### 3. TEST vs PROD Usporedba
```bash
./test-both-environments.sh
```

**Provjeri:**
- ✅ Isti broj `availableFields`
- ✅ Isti field names
- ✅ Ista struktura `userInfo` objekta
- ✅ Isti response format

---

## 🐛 Troubleshooting

### Server ne odgovara:
```bash
# Provjeri je li server pokrenut
curl https://uniformly-credible-opossom.ngrok-free.app/api/health

# Provjeri ngrok
ps aux | grep ngrok
```

### Krivi environment:
```bash
# Provjeri .env
cat .env | grep CERTILIA_BASE_URL

# Prebaci i restartaj
npm run dev:test   # ili dev:prod
```

### Token expired:
```bash
# Dobavi novi token
./test-oauth-flow.sh
```

### Extended info ne vraća podatke:
```bash
# Provjeri da li token ima certilia_tokens
# Mora biti fresh token iz /api/auth/exchange

# Provjeri server logove
tail -f logs/certilia-server-*.log
```

---

## 📊 Expected Responses

### `/api/auth/exchange` Response:
```json
{
  "accessToken": "eyJhbG...",
  "refreshToken": "eyJhbG...",
  "tokenType": "Bearer",
  "expiresIn": 3600,
  "user": {
    "sub": "user_id",
    "firstName": "Ime",
    "lastName": "Prezime",
    "oib": "12345678901",
    "email": "email@example.com",
    "dateOfBirth": "1990-01-01"
  }
}
```

### `/api/user/extended-info` Response:
```json
{
  "userInfo": {
    "sub": "user_id",
    "given_name": "Ime",
    "family_name": "Prezime",
    "oib": "12345678901",
    "email": "email@example.com",
    "birthdate": "1990-01-01",
    ... (svi dostupni fieldovi)
  },
  "availableFields": [
    "sub",
    "given_name",
    "family_name",
    "oib",
    "email",
    "birthdate",
    ...
  ],
  "tokenExpiry": "2025-09-30T18:00:00.000Z"
}
```

---

## 💡 Best Practices

1. **Uvijek testir ajte oba environmenta** nakon promjena
2. **Usporedite responses** da potvrdite konzistentnost
3. **Provjerite server logove** za dodatne informacije
4. **Koristite fresh tokene** za extended info testove
5. **Dokumentirajte razlike** između TEST i PROD ako ih ima

---

## 🔗 Quick Commands

```bash
# Test current environment
./test-oauth-flow.sh

# Test extended info
./test-extended-info.sh <token>

# Test both environments
./test-both-environments.sh

# Compare extended info
./compare-extended-info.sh

# Switch environments
npm run dev:test    # Switch to TEST
npm run dev:prod    # Switch to PROD
```