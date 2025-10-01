# 📝 Certilia Server - CHEATSHEET

## ⚡ OSNOVNE NAREDBE (Copy-Paste)

### 🧪 Pokretanje TEST environment (idp.test.certilia.com):
```bash
npm run dev:test
```

### 🚀 Pokretanje PRODUCTION environment (idp.certilia.com):
```bash
npm run dev:prod
```

**Obje naredbe automatski:**
- ✅ Kopiraju ispravni .env file
- ✅ Pokreću server s nodemon auto-reload
- ✅ Koriste ispravan Certilia endpoint

### Prebacivanje bez pokretanja:
```bash
npm run switch:test    # samo promijeni .env
npm run switch:prod    # samo promijeni .env
npm run dev            # pokreni s trenutnim .env
```

---

## 🌐 KOMPLETNI WORKFLOW

### 3 Terminala Setup:

**Terminal 1 - NGROK:**
```bash
ngrok http --url=uniformly-credible-opossum.ngrok-free.app 3000
```

---

**Terminal 2 - SERVER:**

**Za TEST:**
```bash
cd certilia-server
npm run dev:test
```

**Za PRODUCTION:**
```bash
cd certilia-server
npm run dev:prod
```

---

**Terminal 3 - FLUTTER:**
```bash
cd flutter_certilia/example
flutter run
```

---

### 🔄 Prebacivanje environmenta:
```bash
# U Terminal 2: Ctrl+C (zaustavi server)
# Zatim:
npm run dev:test    # za TEST
# ili
npm run dev:prod    # za PRODUCTION
```

---

## 🔍 PROVJERA

### Koji environment radi?
```bash
# Provjeri logove - tražite liniju:
Certilia URL: https://idp.test.certilia.com      # TEST
Certilia URL: https://idp.certilia.com           # PROD (bez "test")
```

### Provjeri .env file:
```bash
cat .env | grep CERTILIA_BASE_URL
```

---

## 🧪 TESTIRANJE

### Health check:
```bash
curl https://uniformly-credible-opossum.ngrok-free.app/api/health
```

### Kompletan OAuth flow:
```bash
./test-oauth-flow.sh
```

### Extended user info:
```bash
./test-extended-info.sh <access_token>
```

### Test oba environmenta (TEST + PROD):
```bash
./test-both-environments.sh
```

### Usporedi extended info (TEST vs PROD):
```bash
./compare-extended-info.sh
```

📖 **Detaljne upute:** Vidi [TESTING.md](TESTING.md)

---

## 📊 SVE NPM NAREDBE

```bash
npm run dev:test        # Pokreni TEST
npm run dev:prod        # Pokreni PRODUCTION
npm run dev             # Pokreni s trenutnim .env
npm run switch:test     # Switch na TEST (samo .env)
npm run switch:prod     # Switch na PROD (samo .env)
npm start               # Production (bez auto-reload)
npm test                # Run tests
npm run lint            # Lint code
npm run format          # Format code
```

---

## 🐛 TROUBLESHOOTING

### Server ne pokreće pravi environment:
```bash
# Provjeri .env
cat .env | grep CERTILIA_BASE_URL

# Ako je krivo, prebaci i restartaj:
npm run switch:test     # ili switch:prod
# Ctrl+C u server terminalu
npm run dev
```

### Flutter koristi krivi environment:
```bash
# MORA restartati server nakon switcha:
# Terminal gdje radi server:
Ctrl+C
npm run dev:test        # ili dev:prod
```

### Port 3000 zauzet:
```bash
lsof -i :3000           # provjeri što koristi port
kill -9 <PID>           # ubij proces
npm run dev:test        # pokreni ponovno
```

---

## ☁️ CLOUD RUN DEPLOYMENT

```bash
./deploy-cloud-run.sh
# Slijedi upute u skripti
```

---

## 📌 QUICK REFERENCE

| Akcija | Naredba |
|--------|---------|
| Pokreni TEST | `npm run dev:test` |
| Pokreni PROD | `npm run dev:prod` |
| Switch TEST | `npm run switch:test` |
| Switch PROD | `npm run switch:prod` |
| Provjeri env | `cat .env \| grep CERTILIA_BASE` |
| Health check | `curl ...ngrok.../api/health` |
| OAuth test | `./test-oauth-flow.sh` |

---

## 💡 BEST PRACTICE

**Najjednostavnije:**
1. Otvori 3 terminala
2. Terminal 1: `ngrok ...`
3. Terminal 2: `npm run dev:test` (ili `dev:prod`)
4. Terminal 3: `flutter run`

**To je to!** 🎉