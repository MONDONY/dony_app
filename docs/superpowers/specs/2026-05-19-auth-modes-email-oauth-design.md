# Auth Modes — Email OTP & OAuth Direct — Spec

**Date :** 2026-05-19  
**Status :** ✅ Approuvé  
**Scope :** dony_app Flutter + dony-back Spring Boot

---

## 1. Contexte et problèmes résolus

### État actuel (avant cette spec)

| Problème | Impact |
|----------|--------|
| `AuthBloc._checkProfileAfterOAuth` émet `AuthOtpVerified(phoneNumber: email)` pour les nouveaux utilisateurs Google/Apple | Le backend reçoit un email comme numéro E.164 → erreur 422 |
| Un seul mode d'auth : téléphone + SMS OTP | Pas de connexion par email, pas d'inscription directe OAuth |
| `POST /auth/register` exige `phoneNumber` E.164 | Impossible d'inscrire un utilisateur Google/Apple sans numéro |

### Ce qui ne change PAS

- `OnboardingScreen` — inchangé
- `RoleSelectionScreen` — ajout d'un paramètre optionnel `pendingEmail`, comportement identique sans ce paramètre
- `PinSetupScreen`, `LocalAuthScreen`, `HomeScreen` — intouchables
- Flux téléphone existant (SMS OTP) — inchangé fonctionnellement

---

## 2. Les 4 modes d'authentification

```
PhoneAuthScreen
  │
  ├─ [MODE TÉLÉPHONE — défaut]
  │   Saisit numéro → SMS OTP → OtpVerificationScreen(mode: phone)
  │   → AuthOtpVerified → register(phoneNumber, roles) → Home
  │
  ├─ [MODE EMAIL — nouveau]
  │   Tap "Continuer avec une adresse email"
  │   → EmailAuthScreen → POST /auth/email-otp/send
  │   → OtpVerificationScreen(mode: email, contact: email)
  │   → POST /auth/email-otp/verify → AuthEmailOtpVerified(email)
  │   → RoleSelectionScreen(pendingEmail: email)
  │   → AuthRegisterWithEmailRequested(email, roles)
  │   → POST /auth/register(email, roles) → Home
  │
  ├─ [MODE GOOGLE]
  │   Tap "Google" → OAuth Firebase
  │   ├─ User existant (200) → AuthAuthenticated → Home
  │   └─ Nouveau user (404) → AuthOAuthNewUser(email)
  │       → RoleSelectionScreen(pendingEmail: email)
  │       → AuthRegisterWithEmailRequested(email, roles)
  │       → POST /auth/register(email, roles) → Home
  │
  └─ [MODE APPLE — iOS uniquement]
      Tap "Apple" → OAuth Firebase (même flux que Google)
```

---

## 3. Flutter — Composants & State management

### 3.1 Nouveaux fichiers

| Fichier | Rôle |
|---------|------|
| `lib/features/auth/presentation/screens/email_auth_screen.dart` | Saisie email + dispatche `AuthEmailOtpSendRequested` |

### 3.2 Fichiers modifiés

| Fichier | Changements |
|---------|-------------|
| `auth_event.dart` | 3 nouveaux events |
| `auth_state.dart` | 3 nouveaux states |
| `auth_bloc.dart` | 3 nouveaux handlers + correction `_checkProfileAfterOAuth` |
| `auth_repository.dart` | 2 nouvelles méthodes : `sendEmailOtp`, `verifyEmailOtp` |
| `otp_verification_screen.dart` | Paramètre `OtpMode` + `contact` |
| `role_selection_screen.dart` | Paramètre optionnel `pendingEmail` |
| `router.dart` | Nouvelles routes + redirect pour nouveaux states |
| `injection.dart` | Aucun nouveau singleton nécessaire (réutilise `AuthRepository`) |

### 3.3 Nouveaux events

```dart
class AuthEmailOtpSendRequested extends AuthEvent {
  final String email;
  const AuthEmailOtpSendRequested(this.email);
}

class AuthEmailOtpVerifyRequested extends AuthEvent {
  final String email;
  final String code;
  const AuthEmailOtpVerifyRequested({required this.email, required this.code});
}

class AuthRegisterWithEmailRequested extends AuthEvent {
  final String email;
  final List<String> roles;
  const AuthRegisterWithEmailRequested({required this.email, required this.roles});
}
```

### 3.4 Nouveaux states

```dart
class AuthEmailOtpSent extends AuthState {
  final String email;
  const AuthEmailOtpSent(this.email);
}

class AuthEmailOtpVerified extends AuthState {
  final String email;
  const AuthEmailOtpVerified(this.email);
}

class AuthOAuthNewUser extends AuthState {
  final String email;
  const AuthOAuthNewUser(this.email);
}
```

### 3.5 Correction `_checkProfileAfterOAuth`

```dart
// AVANT (bug)
if (e.response?.statusCode == 404) {
  emit(AuthOtpVerified(phoneNumber: _pendingPhoneNumber ?? ''));
}

// APRÈS (corrigé)
if (e.response?.statusCode == 404) {
  final email = _firebaseAuth.currentUser?.email ?? '';
  emit(AuthOAuthNewUser(email));
}
```

### 3.6 Routing — nouveaux states

| State | Route |
|-------|-------|
| `AuthEmailOtpSent(email)` | `/auth/email-otp` — `OtpVerificationScreen(mode: email, contact: email)` |
| `AuthEmailOtpVerified(email)` | `/onboarding/role` avec `extra: {pendingEmail: email}` |
| `AuthOAuthNewUser(email)` | `/onboarding/role` avec `extra: {pendingEmail: email}` |

Nouvelles routes publiques à ajouter dans `_publicRoutes` : `/auth/email`, `/auth/email-otp`.

> **Note routage :** l'`extra` de `/onboarding/role` passe de `String` (initialRole) à `Map<String, String?>` :
> `{'initialRole': 'SENDER', 'pendingEmail': null}` (flux pré-auth)
> `{'initialRole': 'SENDER', 'pendingEmail': 'amadou@gmail.com'}` (flux post-auth email/OAuth)

### 3.7 `OtpVerificationScreen` — adaptation

```dart
enum OtpMode { phone, email }

// Paramètres ajoutés au constructeur :
final OtpMode mode;      // phone (défaut) | email
final String contact;    // numéro ou adresse email

// En mode email :
// - AppBar title : "Vérification email"
// - Subtitle : "Code envoyé à {contact}"
// - Event dispatché : AuthEmailOtpVerifyRequested(email: contact, code: code)
// - Mascotte : DonyMascotteAnimated(type: confiant, size: md)

// En mode phone : comportement actuel inchangé
```

### 3.8 `RoleSelectionScreen` — adaptation

```dart
// Paramètre ajouté :
final String? pendingEmail;   // null → mode pré-auth (existant)

// _proceed() selon le mode :
if (pendingEmail != null) {
  // Mode post-auth (email ou OAuth)
  context.read<AuthBloc>().add(
    AuthRegisterWithEmailRequested(email: pendingEmail!, roles: [role]),
  );
} else {
  // Mode pré-auth (existant) : ActiveRoleCubit + OnboardingCompleted + go('/auth/phone')
}
```

### 3.9 `EmailAuthScreen` — structure

```dart
// DonyPageScaffold(
//   title: 'Connexion par email',
//   scrollable: true,
//   stickyBottom: DonyButton(
//     label: 'Envoyer le code',
//     onPressed: _isValid ? _submit : null,
//   ),
//   body: Column([
//     SizedBox(height: DonySpacing.xl),
//     Center(DonyMascotteAnimated(type: confiant, size: md)),
//     SizedBox(height: DonySpacing.xl),
//     Text('Entre ton email', style: titleLarge),
//     Text('Tu recevras un code à 6 chiffres', style: bodyMedium),
//     SizedBox(height: DonySpacing.lg),
//     DonyTextField(
//       label: 'Adresse email',
//       keyboardType: TextInputType.emailAddress,
//       controller: _emailController,
//       onChanged: (_) => _validate(),
//     ),
//   ]),
// )
// Dispatche AuthEmailOtpSendRequested(email) sur submit
```

---

## 4. Backend — Nouveaux endpoints & service email

### 4.1 Nouveau package `com.dony.api.emailotp`

```
emailotp/
├── EmailOtpEntity.java
├── EmailOtpRepository.java
├── EmailOtpService.java
├── EmailOtpController.java
└── ResendEmailService.java
```

### 4.2 Migration Flyway V(n+1)

```sql
CREATE TABLE email_otp_tokens (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email      VARCHAR(255) NOT NULL,
  code_hash  VARCHAR(60)  NOT NULL,   -- BCrypt(code, strength=10)
  expires_at TIMESTAMP    NOT NULL,   -- now() + 10 minutes
  used_at    TIMESTAMP,
  created_at TIMESTAMP    DEFAULT NOW()
);
CREATE INDEX idx_email_otp_email ON email_otp_tokens(email);
```

### 4.3 Endpoints

**`POST /auth/email-otp/send`** — public, pas d'auth Firebase requis

```json
// Request
{ "email": "amadou@gmail.com" }

// Response 200
{ "expiresAt": "2026-05-19T10:15:00Z" }

// Erreurs
// 422 — email invalide (format)
// 429 — ≥ 3 envois sur les 5 dernières minutes pour cet email
```

Logique :
1. Valider format email
2. Vérifier rate-limit : `COUNT WHERE email=? AND created_at > now()-5min` ≥ 3 → 429
3. Générer code = 6 chiffres aléatoires (`SecureRandom`)
4. Stocker `{email, BCrypt(code), now()+10min}`
5. Envoyer email via Resend

**`POST /auth/email-otp/verify`** — public

```json
// Request
{ "email": "amadou@gmail.com", "code": "123456" }

// Response 200 (succès, corps vide)

// Erreurs
// 400 — code invalide ou expiré
// 429 — > 5 tentatives échouées sur le même token
```

Logique :
1. Trouver le token le plus récent non utilisé pour cet email
2. Vérifier `expires_at > now()`
3. `BCryptPasswordEncoder.matches(code, code_hash)` → 400 si false
4. Marquer `used_at = now()`

### 4.4 Mise à jour `POST /auth/register`

```java
// Avant
@NotBlank @Pattern(regexp = "\\+[1-9]\\d{7,14}")
private String phoneNumber;

// Après
@Nullable
@Pattern(regexp = "\\+[1-9]\\d{7,14}")
private String phoneNumber;

@Nullable
@Email
private String email;
```

Validation dans le service :
- Firebase token provider = `phone` → `phoneNumber` obligatoire
- Firebase token provider = `google.com` ou `apple.com` → `email` obligatoire
- Sinon → 422

### 4.5 Service email — Resend

```yaml
# application.yml
dony:
  email:
    resend-api-key: ${RESEND_API_KEY}
    from-address: noreply@dony.app
    otp-template: "Ton code dony est : %s. Valable 10 minutes."
```

`ResendEmailService` : appel HTTP `POST https://api.resend.com/emails` via `RestClient`.

### 4.6 `SecurityConfig`

Ajouter aux endpoints publics :
```java
"/auth/email-otp/send",
"/auth/email-otp/verify"
```

---

## 5. Gestion des erreurs

| Scénario | Comportement Flutter |
|----------|---------------------|
| Email invalide (format) | Validation locale inline, bouton désactivé |
| 429 trop de demandes | `DonySnackbar(type: warning, "Trop de tentatives, réessaie dans 5 min")` |
| Code OTP expiré | `DonySnackbar(type: error, "Code expiré")` + bouton "Renvoyer" actif |
| Code OTP invalide | Champ pinput shake animation + message d'erreur inline |
| Réseau indisponible | `DonySnackbar(type: error, "Vérifie ta connexion")` |
| OAuth annulé par l'utilisateur | Retour silencieux à `PhoneAuthScreen` |
| OAuth erreur serveur | `DonySnackbar(type: error, message)` |

---

## 6. Tests

### Flutter (≥ 90 % couverture)

- **BLoC** : `blocTest` pour les 3 nouveaux handlers + correction `_checkProfileAfterOAuth`
- **Widget** : `EmailAuthScreen` (validation, loading, submit)
- **Widget** : `OtpVerificationScreen` mode email (titre, subtitle, event dispatché)
- **Widget** : `RoleSelectionScreen` mode `pendingEmail` (dispatch `AuthRegisterWithEmailRequested`)
- **Widget** : `PhoneAuthScreen` — lien email visible, tap navigue vers `/auth/email`

### Backend (≥ 90 % couverture)

- **Unit** : `EmailOtpService` (génération, rate-limit, vérification, expiry, used_at)
- **Integration** : `EmailOtpController` (MockMvc) — send 200, send 429, verify 200, verify 400, verify 429
- **Unit** : `AuthService.register` — provider phone vs google.com vs apple.com
- Mock `ResendEmailService` dans les tests (ne pas appeler l'API réelle)

---

## 7. Décisions techniques

| Décision | Raison |
|----------|--------|
| Resend comme service email | API simple (1 appel REST), bonne DX, pas de SDK lourd |
| BCrypt pour stocker le code OTP | Cohérence avec le reste de la sécurité du projet |
| Rate-limit applicatif (pas Nginx) | Nginx rate-limit global sur `/auth/**` — besoin de granularité par email |
| `pendingEmail` dans `RoleSelectionScreen` | Évite de créer un écran dupliqué ; le comportement pré-auth reste inchangé |
| Pas de vérification email supplémentaire pour Google/Apple | L'identité est déjà vérifiée par l'OAuth provider — double vérification = friction inutile |
