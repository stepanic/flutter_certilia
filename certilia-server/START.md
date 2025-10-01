# 🚀 Certilia Server - START GUIDE

## ⚡ JEDINSTVENI NAČIN POKRETANJA

### 📋 Preduvjeti
1. Node.js instaliran (`npm install` izvršen)
2. ngrok pokrenut u drugom terminalu

---

## 🎯 STANDARDNE NAREDBE - DVA ENVIRONMENTA

### **OPCIJA A: Direktno pokretanje (automatski switch)** ⭐

#### 🧪 Za TEST environment (Certilia TEST):
```bash
npm run dev:test
```
**Koristi:** `idp.test.certilia.com`

#### 🚀 Za PRODUCTION environment (Certilia PROD):
```bash
npm run dev:prod
```
**Koristi:** `idp.certilia.com`

---

**Ove naredbe će:**
- ✅ Automatski kopirati ispravni `.env` file
- ✅ Pokrenuti server s auto-reload
- ✅ Server odmah radi s odabranim environmentom
- ✅ Ne morate ručno prebacivati konfiguraciju

---

### **OPCIJA B: Switch pa restart**

Ako vam server već radi, možete prebaciti environment bez gašenja:

#### 1. Prebaci environment:
```bash
# Za TEST
npm run switch:test

# Za PRODUCTION
npm run switch:prod
```

#### 2. Restartaj server:
```bash
# Zaustavi trenutni (Ctrl+C), pa pokreni:
npm run dev
```

---

## 🌐 Kompletni Workflow

### Terminal 1 - NGROK:
```bash
ngrok http --url=uniformly-credible-opossum.ngrok-free.app 3000
```
☝️ **Držite ovo otvoreno!**

---

### Terminal 2 - SERVER:

**Za TEST Certilia:**
```bash
cd certilia-server
npm run dev:test
```

**Za PRODUCTION Certilia:**
```bash
cd certilia-server
npm run dev:prod
```

---

### Terminal 3 - FLUTTER CLIENT:
```bash
cd flutter_certilia/example
flutter run
```

---

### 🔄 Prebacivanje između environmenta:
```bash
# Zaustavite server (Ctrl+C u Terminalu 2)
# Zatim pokrenite drugi environment:

npm run dev:test    # za TEST
# ili
npm run dev:prod    # za PRODUCTION
```

---

## 📊 SVE DOSTUPNE NAREDBE

| Naredba | Što radi |
|---------|----------|
| `npm run dev:test` | Pokreni server s TEST env |
| `npm run dev:prod` | Pokreni server s PROD env |
| `npm run dev` | Pokreni server (koristi trenutni .env) |
| `npm run switch:test` | Prebaci na TEST (bez pokretanja) |
| `npm run switch:prod` | Prebaci na PROD (bez pokretanja) |
| `npm start` | Production start (bez auto-reload) |

---

## ✅ Kako Provjeriti Koji Environment Radi

Pogledajte server logove nakon pokretanja:

### TEST environment:
```
Server started on port 3000
Certilia URL: https://idp.test.certilia.com
```

### PRODUCTION environment:
```
Server started on port 3000
Certilia URL: https://idp.certilia.com
```

---

## 🐛 Troubleshooting

### Problem: Server ne pokreće environment koji sam odabrao
**Rješenje:** Provjerite `.env` file:
```bash
cat .env | grep CERTILIA_BASE_URL
```

Ako je krivo, pokrenite:
```bash
# Za TEST
npm run switch:test

# Za PRODUCTION
npm run switch:prod

# Pa restartajte server
npm run dev
```

### Problem: Flutter app koristi krivi environment
**Rješenje:** Restartajte server nakon switch-a!
```bash
Ctrl+C   # u terminalu gdje radi server
npm run dev
```

---

## 📝 Brze Naredbe (Copy-Paste Ready)

### 🧪 Pokretanje s TEST (idp.test.certilia.com):
```bash
# Terminal 1 - ngrok
ngrok http --url=uniformly-credible-opossum.ngrok-free.app 3000

# Terminal 2 - Server TEST
cd certilia-server && npm run dev:test

# Terminal 3 - Flutter
cd flutter_certilia/example && flutter run
```

---

### 🚀 Pokretanje s PRODUCTION (idp.certilia.com):
```bash
# Terminal 1 - ngrok (isti kao gore)
ngrok http --url=uniformly-credible-opossum.ngrok-free.app 3000

# Terminal 2 - Server PRODUCTION
cd certilia-server && npm run dev:prod

# Terminal 3 - Flutter
cd flutter_certilia/example && flutter run
```

---

## 🔄 Prebacivanje Environment-a (ako server već radi)

```bash
# Zaustavi server (Ctrl+C)

# Odaberi:
npm run dev:test    # za TEST
npm run dev:prod    # za PRODUCTION
```

---

## 🎯 PREPORUKA

**Najjednostavnije:** Koristite `npm run dev:test` ili `npm run dev:prod`

Ove dvije naredbe rade SVE automatski! 🚀