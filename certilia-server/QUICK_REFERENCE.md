# ⚡ QUICK REFERENCE - Certilia Server

## 🎯 DVA ENVIRONMENTA - DVE NAREDBE

```
┌─────────────────────────────────────────────────────┐
│                                                     │
│  🧪 TEST ENVIRONMENT                                │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  │
│                                                     │
│  Certilia: idp.test.certilia.com                   │
│  Client ID: 991dffbb...                            │
│                                                     │
│  Pokretanje:                                        │
│  $ npm run dev:test                                 │
│                                                     │
└─────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────┐
│                                                     │
│  🚀 PRODUCTION ENVIRONMENT                          │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  │
│                                                     │
│  Certilia: idp.certilia.com                        │
│  Client ID: 1a6ec445...                            │
│                                                     │
│  Pokretanje:                                        │
│  $ npm run dev:prod                                 │
│                                                     │
└─────────────────────────────────────────────────────┘
```

---

## 📋 KOMPLETAN WORKFLOW

```
Terminal 1          Terminal 2              Terminal 3
─────────          ──────────              ──────────
NGROK              SERVER                  FLUTTER

ngrok http...      npm run dev:test        flutter run
                   (ili dev:prod)
```

---

## 🔄 PREBACIVANJE

```bash
# Terminal 2:
Ctrl+C                 # Zaustavi server

npm run dev:test       # Za TEST
# ili
npm run dev:prod       # Za PRODUCTION
```

---

## ✅ VERIFIKACIJA

### Koji environment radi?

```bash
# Provjeri logove - tražite:
Certilia URL: https://idp.test.certilia.com      # ← TEST
Certilia URL: https://idp.certilia.com           # ← PROD
```

### Ili provjeri .env:

```bash
cat .env | grep CERTILIA_BASE_URL
```

---

## 🧪 TESTIRANJE

```bash
# Osnovni OAuth flow
./test-oauth-flow.sh

# Extended user info
./test-extended-info.sh <token>

# Oba environmenta
./test-both-environments.sh

# Usporedba
./compare-extended-info.sh
```

---

## 📚 DOKUMENTACIJA

| File | Svrha |
|------|-------|
| **START.md** | Detaljne startup upute |
| **CHEATSHEET.md** | Brze copy-paste naredbe |
| **TESTING.md** | Testing guide |
| **README.md** | Tehnička dokumentacija |

---

## 🎯 NAJČEŠĆE NAREDBE

```bash
npm run dev:test        # Start TEST
npm run dev:prod        # Start PRODUCTION
npm run dev             # Start s trenutnim .env
npm run switch:test     # Prebaci na TEST
npm run switch:prod     # Prebaci na PROD
```

---

## 💡 TO JE TO!

**Zapamtite samo 2 naredbe:**

```bash
npm run dev:test    # za TEST Certilia
npm run dev:prod    # za PROD Certilia
```

**Gotovo!** 🎉