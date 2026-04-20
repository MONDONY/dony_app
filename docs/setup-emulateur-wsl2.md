# Setup : Émulateur Android (Windows) + Flutter (WSL2)

> Guide de référence pour connecter l'émulateur Android Studio (Windows) à Flutter dans WSL2.
> Méthode validée : portproxy Windows → ADB server WSL2.

---

## Contexte technique

L'ADB WSL2 et l'ADB Windows peuvent avoir des versions incompatibles, ce qui cause l'erreur `offline`.
La solution retenue : utiliser le **serveur ADB Windows** depuis WSL2 via un portproxy.

```
WSL2 (adb client)
      │
      │ ADB_SERVER_SOCKET=tcp:172.19.48.1:5037
      ▼
Windows portproxy (172.19.48.1:5037 → 127.0.0.1:5037)
      │
      ▼
Windows ADB server (127.0.0.1:5037)
      │
      ▼
Émulateur Android (emulator-5554)
```

---

## Configuration initiale (une seule fois)

### Sur Windows — PowerShell en administrateur

```powershell
# 1. Règle pare-feu pour le port ADB server
netsh advfirewall firewall add rule name="ADB Server WSL2" dir=in action=allow protocol=TCP localport=5037

# 2. Portproxy : expose le serveur ADB Windows vers l'interface WSL2
netsh interface portproxy add v4tov4 listenaddress=172.19.48.1 listenport=5037 connectaddress=127.0.0.1 connectport=5037
```

> Ces deux commandes n'ont besoin d'être lancées qu'**une seule fois** (persistent après redémarrage).

### Dans WSL — ajouter dans `~/.bashrc` (déjà fait)

```bash
export ADB_SERVER_SOCKET=tcp:172.19.48.1:5037
```

Cette variable indique à l'ADB WSL2 d'utiliser le serveur ADB Windows.

---

## Procédure de démarrage (à chaque session)

### Étape 1 — Démarrer l'émulateur sur Windows

Lance Android Studio → Device Manager → Start.

Attends qu'il soit **complètement démarré** (écran d'accueil Android visible).

---

### Étape 2 — Vérifier que l'émulateur est reconnu sur Windows

Dans **PowerShell Windows** :
```powershell
.\adb devices
```

Résultat attendu :
```
List of devices attached
emulator-5554   device
```

> Si `offline` : redémarre l'émulateur.

---

### Étape 3 — Exposer le backend Spring Boot à l'émulateur

Dans **WSL** (le backend tourne dans WSL, l'émulateur est sur Windows) :
```bash
adb -s emulator-5554 reverse tcp:8080 tcp:8080
```

Résultat attendu : `8080`

---

### Étape 4 — Vérifier Flutter

```bash
flutter devices
```

Résultat attendu :
```
Found 2 connected devices:
  sdk gphone16k x86 64 (mobile) • emulator-5554 • android-x64 • Android XX
  Linux (desktop)               • linux          • linux-x64   • Ubuntu XX
```

---

### Étape 5 — Lancer l'app

```bash
cd /mnt/c/Users/abou5/Desktop/mon-dony/dony_app
flutter run --dart-define-from-file=env.dev.json -d emulator-5554
```

---

## Nettoyage (si session cassée)

**Dans WSL :**
```bash
adb kill-server
```

**Dans PowerShell Windows :**
```powershell
.\adb kill-server
.\adb start-server
.\adb devices
```

Puis reprendre à l'étape 3.

---

## Vérifier / recréer le portproxy (si IP change)

L'IP Windows (`172.19.48.1`) peut changer après redémarrage du PC.

```bash
# Vérifier l'IP actuelle depuis WSL
ip route show | grep default | awk '{print $3}'
```

Si l'IP a changé (ex: `172.20.48.1`), recréer le portproxy sur Windows :
```powershell
# Supprimer l'ancien
netsh interface portproxy delete v4tov4 listenaddress=172.19.48.1 listenport=5037

# Créer avec la nouvelle IP
netsh interface portproxy add v4tov4 listenaddress=172.20.48.1 listenport=5037 connectaddress=127.0.0.1 connectport=5037
```

Et mettre à jour `~/.bashrc` dans WSL :
```bash
export ADB_SERVER_SOCKET=tcp:172.20.48.1:5037
```

---

## Dépannage

| Symptôme | Cause probable | Solution |
|----------|---------------|----------|
| `emulator-5554 offline` sur Windows | Émulateur pas prêt | Attendre ou redémarrer l'émulateur |
| `adb devices` vide dans WSL | ADB_SERVER_SOCKET non défini | `export ADB_SERVER_SOCKET=tcp:172.19.48.1:5037` |
| `Connection timed out` sur port 5037 | Portproxy absent ou mauvaise IP | Recréer le portproxy (voir section ci-dessus) |
| Backend inaccessible dans l'app | `adb reverse` non fait | Refaire l'étape 3 |
| IP Windows a changé | Redémarrage du PC | Vérifier l'IP et mettre à jour portproxy + bashrc |
