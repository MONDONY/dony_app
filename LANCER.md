# 🚀 Lancer dony — Front + Back sur Android & iPhone physiques

Guide complet pour démarrer le backend Spring Boot **et** l'app Flutter sur les deux téléphones physiques (Android + iPhone), en environnement **dev**.

---

## 📋 Pré-requis (une seule fois)

- **Docker / OrbStack** lancé (pour PostgreSQL).
- **Java 21** + Maven wrapper (`./mvnw`) — déjà dans `dony-back`.
- **Flutter** installé (`flutter --version`).
- Les deux téléphones **branchés en USB** et **sur le même Wi-Fi que le Mac** (réseau `192.168.1.x`).
  - iPhone : mode développeur activé + appareil approuvé dans Xcode.
  - Android : débogage USB activé.

Vérifier que les deux appareils sont vus :
```bash
flutter devices
```
Tu dois voir :
| Appareil | ID (`-d`) | OS |
|---|---|---|
| 📱 Android physique | `9b01005930533132380051fb249c8c` | Android 15 |
| 🍎 iPhone physique | `00008101-001E698C3E92001E` | iOS 26.5 |

> Les IDs peuvent changer si tu rebranches/réinstalles. En cas de doute, relance `flutter devices` et reprends l'ID affiché. Tu peux aussi viser par nom : `-d "iPhone de Aboubakar siriki"`.

---

## 🌐 Étape 0 — Vérifier l'IP du Mac (IMPORTANT)

Un téléphone **physique** ne peut PAS utiliser `localhost` ni `10.0.2.2` (ça, c'est pour l'émulateur).
Il doit joindre le backend via l'**IP LAN du Mac**.

```bash
ipconfig getifaddr en0
```

Si l'IP **n'est plus** `192.168.1.161`, mets à jour `env.dev.json` :
```bash
NEW_IP=$(ipconfig getifaddr en0) && \
sed -i '' "s|\"API_BASE_URL\": \"http://[^\"]*\"|\"API_BASE_URL\": \"http://$NEW_IP:8080/api/v1\"|" \
  /Users/aboubakardiakite/Desktop/dony/dony_app/env.dev.json && \
grep API_BASE_URL /Users/aboubakardiakite/Desktop/dony/dony_app/env.dev.json
```

> ⚠️ Sur macOS, `sed -i` exige un argument vide `''` juste après `-i`.

---

## 🖥️ Étape 1 — Lancer le BACKEND (Spring Boot)

> Garde ce terminal **ouvert** tout du long.

```bash
cd /Users/aboubakardiakite/Desktop/dony/dony-back

# 1. Charger les secrets (Stripe, Cloudflare R2, Firebase, Google…)
set -a && source .env.dev && set +a

# 2. Démarrer la base + services (PostgreSQL 5432, MinIO, Adminer, Stripe CLI)
docker compose -f docker-compose.dev.yml up -d

# 3. (optionnel) attendre que la DB soit prête
docker inspect --format '{{.State.Health.Status}}' dony_db    # → healthy

# 4. Démarrer Spring Boot (profil dev par défaut)
./mvnw spring-boot:run
```

**Vérifier que le back est UP** (dans un autre terminal) :
```bash
curl http://localhost:8080/api/v1/actuator/health    # → {"status":"UP"}
```

> ⚠️ Lance **Docker AVANT** `./mvnw`, sinon Spring crashe avec `Connection to localhost:5432 refused`.

---

## 📱 Étape 2 — Lancer le FRONT (Flutter)

> Un terminal **par téléphone**. Les deux utilisent **`env.dev.json`** (IP LAN).

### Android physique → SMS fonctionne ✅
```bash
cd /Users/aboubakardiakite/Desktop/dony/dony_app
flutter run --dart-define-from-file=env.dev.json -d 9b01005930533132380051fb249c8c
```

### iPhone physique → email seulement (SMS bloqué) ⚠️
```bash
cd /Users/aboubakardiakite/Desktop/dony/dony_app
flutter run --dart-define-from-file=env.dev.json -d 00008101-001E698C3E92001E
```

Une fois lancé, dans la session `flutter run` :
- `r` → hot reload 🔥 · `R` → hot restart · `q` → quitter · `d` → détacher (laisse l'app ouverte).

---

## 🔐 Connexion en DEV

| Méthode | Android | iPhone |
|---|---|---|
| **Email** | ✅ | ✅ |
| **Téléphone (SMS)** | ✅ via numéro de test Firebase | ❌ bloqué (voir note APNs) |

### Login par SMS (numéro de test — Android)
1. Écran login → **Téléphone** → `0766334898`
2. Code : `123456` (aucun vrai SMS envoyé)

> Le numéro `+33766334898` doit être déclaré dans
> **Firebase Console → Authentication → Sign-in method → Phone → Numéros de test** avec le code `123456`.

### Login par Email (dev)
- Le backend (profil dev) **log le code OTP** dans la console Spring Boot :
  `📧 [DEV] Code OTP pour {email} : {code}` — pas besoin de recevoir le mail.

### Pourquoi le SMS ne marche pas sur iPhone ❓
Firebase Phone Auth sur iOS exige un **push silencieux APNs**, qui nécessite un **compte Apple Developer payant (99 $/an)** + une **clé APNs .p8** uploadée dans Firebase Console.
Tant que ce n'est pas configuré → sur iPhone, utiliser l'**email**.

Quand le compte Apple sera actif :
1. Créer une clé **APNs .p8** (Apple Developer → Keys).
2. L'uploader dans **Firebase Console → Cloud Messaging** ET **Authentication → Phone**.
3. Ajouter la capability **Push Notifications** + entitlement `aps-environment` au projet iOS.
4. Retirer le garde `#if !DEBUG` dans `ios/Runner/AppDelegate.swift`.

---

## 🧯 Dépannage

| Problème | Cause / Solution |
|---|---|
| `Connection refused` sur téléphone | IP périmée → refaire **Étape 0**. Ou téléphone pas sur le même Wi-Fi. |
| `{"status":"DOWN"}` ou rien sur `:8080` | Backend pas lancé / Docker pas démarré → **Étape 1**. |
| `Connection to localhost:5432 refused` | Docker lancé après Spring → relancer `docker compose ... up -d` puis `./mvnw`. |
| Téléphone absent de `flutter devices` | Rebrancher USB, déverrouiller, approuver l'ordinateur (iPhone) / autoriser le débogage (Android). |
| iPhone : erreur de signature | Vérifier `DEVELOPMENT_TEAM = F5Q74US8XS` et bundle id `com.dony.dony` dans Xcode. |
| « code invalide » au SMS | Le numéro de test n'est pas (ou plus) dans Firebase Console, ou mauvais code. |
| App reste connectée (pas d'écran login) | Session restaurée → **Profil/Réglages → Déconnexion** avant de tester un autre login. |

---

## ⚡ Récap express

```bash
# --- BACK (terminal 1) ---
cd /Users/aboubakardiakite/Desktop/dony/dony-back
set -a && source .env.dev && set +a
docker compose -f docker-compose.dev.yml up -d
./mvnw spring-boot:run

# --- FRONT Android (terminal 2) ---
cd /Users/aboubakardiakite/Desktop/dony/dony_app
flutter run --dart-define-from-file=env.dev.json -d 9b01005930533132380051fb249c8c

# --- FRONT iPhone (terminal 3) ---
cd /Users/aboubakardiakite/Desktop/dony/dony_app
flutter run --dart-define-from-file=env.dev.json -d 00008101-001E698C3E92001E
```
