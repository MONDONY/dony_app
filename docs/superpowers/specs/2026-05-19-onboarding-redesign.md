# Onboarding Redesign — Spec

**Date :** 2026-05-19  
**Status :** ✅ Approuvé  
**Scope :** dony_app Flutter — parcours premier lancement uniquement

---

## 1. Contexte et problèmes résolus

### État actuel (avant cette spec)

| Écran | Problème |
|-------|----------|
| `OnboardingScreen` | Les 2 boutons ("J'envoie un colis" / "Je suis voyageur") appellent la même fonction — le rôle n'est jamais capturé |
| `PhoneAuthScreen` | Seule méthode d'auth : téléphone. Pas de Google ni Apple. |
| Auth en général | Pas de mascotte sur l'écran d'auth ni sur l'OTP |

### Ce qui ne change PAS

- `SplashScreen` — inchangé
- `OnboardingScreen` — inchangé (mascotte `joyeux`, feature cards, les 2 boutons)
- `OtpVerificationScreen` — inchangé (sauf ajout mascotte)
- `PinSetupScreen` — inchangé (a déjà `securise` + step indicator)
- `LocalAuthScreen` — inchangé
- `HomeScreen` et toute la navigation principale — **intouchable**

---

## 2. Nouveau parcours — premier lancement

```
Splash
  │
  ├─ onboarding_done = false ──→ OnboardingScreen (existant)
  │                                    │
  │                           "J'envoie un colis"  →  RoleScreen (pré-sélection: SENDER)
  │                           "Je suis voyageur"   →  RoleScreen (pré-sélection: TRAVELER)
  │                                    │
  │                              RoleScreen (NEW)
  │                                    │
  │                              AuthScreen (REDESIGN)
  │                              ┌─────┴──────────────────────┐
  │                          Téléphone                  Google / Apple
  │                              │                            │
  │                         OtpScreen              Firebase OAuth flow
  │                              └─────────┬──────────────────┘
  │                                   PinSetupScreen (si nouveau compte)
  │                                        │
  └─ onboarding_done = true ──→       HomeScreen ←──────────────────
         │
    FirebaseUser null ──→ AuthScreen
    FirebaseUser ok   ──→ LocalAuthScreen → HomeScreen
```

**Cas utilisateur existant qui revient :**  
`Splash → LocalAuthScreen → HomeScreen` — aucun écran d'onboarding, aucun écran de rôle.

---

## 3. Écrans à créer / modifier

### 3.1 RoleScreen — NOUVEAU

**Route :** `/onboarding/role`  
**Fichier :** `lib/features/auth/presentation/screens/role_selection_screen.dart`

#### Comportement

- Reçoit un paramètre `initialRole` (`SENDER` ou `TRAVELER`) passé via `GoRouter extra`
- La mascotte change selon le rôle sélectionné :
  - `SENDER` sélectionné → `DonyMascotteAnimated(type: DonyMascotteType.tenantColis, size: DonyMascotteSize.md)`
  - `TRAVELER` sélectionné → `DonyMascotteAnimated(type: DonyMascotteType.enCourse, size: DonyMascotteSize.md)`
- Transition mascotte : `AnimatedSwitcher(duration: 250ms)` entre les deux types
- Les deux rôles sont toujours inscrits côté backend (`['TRAVELER', 'SENDER']`) — ce choix est la **préférence d'affichage** (rôle actif par défaut dans `ActiveRoleCubit`)
- Bouton "Continuer" → `/auth/phone` en passant le rôle choisi

#### Layout

```
SafeArea
└── Column
    ├── Spacer(flex:1)
    ├── AnimatedSwitcher → DonyMascotteAnimated (tenantColis ou enCourse · md)
    ├── SizedBox(height: DonySpacing.lg)
    ├── Titre : "Comment tu utilises dony ?"  (tt.headlineLarge)
    ├── Sous-titre : "Ton profil principal — tu peux changer à tout moment"  (tt.bodyMedium)
    ├── SizedBox(height: DonySpacing.xl)
    ├── _RoleCard(role: SENDER, active: selectedRole == SENDER)
    ├── SizedBox(height: DonySpacing.sm)
    ├── _RoleCard(role: TRAVELER, active: selectedRole == TRAVELER)
    ├── SizedBox(height: DonySpacing.xs)
    ├── Text "Tu auras accès aux deux modes"  (tt.bodySmall, cs.onSurfaceVariant)
    ├── Spacer(flex:2)
    └── _StickyBottom → DonyButton(label: 'Continuer', onPressed: _proceed)
```

#### `_RoleCard` widget

```dart
// Sélectionnable, borde cs.primary si actif, cs.outline sinon
// Contient : icône (tenantColis/enCourse asset ou Icons), titre, description
// onTap → setState selectedRole (local ValueNotifier — pas de BLoC pour ce choix UI)
```

#### Navigation depuis OnboardingScreen

`OnboardingScreen` passe le rôle implicite dans l'extra GoRouter :
```dart
// Bouton "J'envoie un colis"
context.go('/onboarding/role', extra: 'SENDER');
// Bouton "Je suis voyageur"
context.go('/onboarding/role', extra: 'TRAVELER');
```

Le `OnboardingCompleted` BLoC event est émis dans `RoleScreen._proceed()` (plus dans OnboardingScreen).

---

### 3.2 PhoneAuthScreen — REDESIGN

**Route :** `/auth/phone` (identique, même fichier)  
**Fichier :** `lib/features/auth/presentation/screens/phone_auth_screen.dart`

#### Changements vs existant

| Avant | Après |
|-------|-------|
| Pas de mascotte | `DonyMascotteAnimated(type: confiant, size: sm)` à côté du logo |
| Téléphone seul | Téléphone + séparateur + Google (+ Apple sur iOS) |
| Logo + "Bienvenue" | Logo + mascotte inline + "Bienvenue" |

#### Layout

```
SafeArea
└── Column
    ├── Expanded → SingleChildScrollView
    │   └── DonyLayout.constrained
    │       └── Column(crossAxisAlignment: start)
    │           ├── Row : [DonyMascotteAnimated(confiant, sm)] + [DonyLogo(48)]
    │           ├── SizedBox(DonySpacing.lg)
    │           ├── Text "Bienvenue"  (tt.displayLarge)
    │           ├── Text "Crée ton compte ou connecte-toi"  (tt.bodyLarge)
    │           ├── SizedBox(DonySpacing.xxl)
    │           ├── Label "NUMÉRO DE TÉLÉPHONE"
    │           └── PhoneInputRow (flag + dialCode + TextFormField) — existant
    └── _PinnedBottom (sticky)
        ├── DonyButton "Recevoir le code SMS"  (primary)
        ├── _OrDivider "ou connexion rapide"
        ├── if Platform.isIOS:
        │     Row [ _SocialBtn(Google, flex:1), _SocialBtn(Apple, flex:1) ]
        │   else:
        │     _SocialBtn(Google, fullWidth: true)
        └── Text CGU (bodySmall)
```

#### Boutons sociaux

**Google Sign-In :**
- Package : `google_sign_in`
- Flow : `GoogleSignIn().signIn()` → `GoogleAuthProvider.credential(...)` → `FirebaseAuth.signInWithCredential(...)`
- Succès → même handler que `AuthPhoneVerified` (vérifie si compte existe → `AuthAuthenticated` ou `AuthOtpVerified`)
- Icône : SVG Google officiel ou `Icons.g_mobiledata` en attendant les assets

**Apple Sign-In :**
- Package : `sign_in_with_apple`
- Condition d'affichage : `Platform.isIOS` uniquement
- Flow : `SignInWithApple.getAppleIDCredential(...)` → `OAuthProvider('apple.com').credential(...)` → `FirebaseAuth.signInWithCredential(...)`
- Obligatoire App Store si Google est présent (règle 4.8)

#### Nouveaux events AuthBloc

```dart
class AuthGoogleSignInRequested extends AuthEvent { const AuthGoogleSignInRequested(); }
class AuthAppleSignInRequested  extends AuthEvent { const AuthAppleSignInRequested(); }
```

Les deux handlers réutilisent la logique de `_onPhoneVerified` après connexion Firebase (getProfile → 200 : `AuthAuthenticated`, 404 : `AuthOtpVerified` → `AuthRegisterRequested`).

---

### 3.3 OtpVerificationScreen — mascotte uniquement

**Changement :** Ajouter `DonyMascotteAnimated(type: DonyMascotteType.confiant, size: DonyMascotteSize.md)` dans la zone scrollable, entre le `DonyLogo` existant et le titre "Vérification". Insertion d'un `SizedBox(height: DonySpacing.lg)` entre la mascotte et le titre. Aucun autre changement de logique ou de layout.

---

## 4. État du rôle — persistance et ActiveRoleCubit

Le rôle traverse 3 étapes entre la sélection et l'activation :

**Étape 1 — RoleScreen._proceed() :**
```dart
// Persister immédiatement dans Hive avant de naviguer
await Hive.box('user_prefs').put('pending_preferred_role', selectedRole); // 'SENDER' ou 'TRAVELER'
context.read<AuthBloc>().add(const OnboardingCompleted());
context.go('/auth/phone');
```

**Étape 2 — AuthBloc._onRegisterRequested(), après emit(AuthAuthenticated(user)) :**
```dart
// Lire et appliquer la préférence persistée
final role = Hive.box('user_prefs').get('pending_preferred_role', defaultValue: 'SENDER') as String;
await Hive.box('user_prefs').put('preferred_role', role);
// ActiveRoleCubit sera mis à jour depuis le BlocListener dans le widget racine
// qui écoute AuthAuthenticated et appelle context.read<ActiveRoleCubit>().setRole(role)
```

**Étape 3 — App.dart ou main_shell.dart :**  
Le `BlocListener<AuthBloc>` existant qui gère `AuthAuthenticated` est étendu pour appeler `context.read<ActiveRoleCubit>().setRole(preferredRole)`.

Le backend continue d'inscrire `['TRAVELER', 'SENDER']` — le rôle choisi est une préférence d'affichage locale uniquement.

---

## 5. Routing — modifications router.dart

```dart
// Ajouter dans la section Auth (hors shell) :
GoRoute(
  path: '/onboarding/role',
  builder: (context, state) {
    final initialRole = state.extra as String? ?? 'SENDER';
    return RoleSelectionScreen(initialRole: initialRole);
  },
),

// Ajouter '/onboarding/role' dans _publicRoutes :
const _publicRoutes = {
  '/splash',
  '/onboarding',
  '/onboarding/role',   // ← NEW
  '/auth/phone',
  '/auth/otp',
  '/auth/pin-setup',
  '/auth/local',
};
```

---

## 6. Dépendances à ajouter — pubspec.yaml

```yaml
dependencies:
  google_sign_in: ^6.2.1
  sign_in_with_apple: ^6.1.2
```

**Configuration Firebase requise :**
- Google : SHA-1 dans Firebase Console + `google-services.json` (déjà présent si Firebase Phone est configuré)
- Apple : Service ID dans Apple Developer + configuration Firebase Auth provider Apple

---

## 7. Tests à écrire

### Bloc tests (auth_bloc_test.dart)
- `AuthGoogleSignInRequested` → émet `AuthLoading` puis `AuthAuthenticated` (compte existant)
- `AuthGoogleSignInRequested` → émet `AuthLoading` puis `AuthOtpVerified` (nouveau compte)
- `AuthAppleSignInRequested` → idem

### Widget tests
- `RoleSelectionScreen` : clic sur "Expéditeur" → mascotte `tenantColis` visible, carte active
- `RoleSelectionScreen` : clic sur "Voyageur" → mascotte `enCourse` visible
- `PhoneAuthScreen` : sur iOS → bouton Apple présent ; sur Android → absent
- `PhoneAuthScreen` : sur Android → bouton Google pleine largeur

### Couverture cible : ≥ 90 %

---

## 8. Critères d'acceptation

- [ ] Premier lancement : `Splash → Onboarding → RoleScreen → AuthScreen → OTP → PIN → Home`
- [ ] La mascotte change selon le rôle sélectionné dans `RoleScreen` (animation `AnimatedSwitcher`)
- [ ] Sur Android : Google pleine largeur, pas d'Apple
- [ ] Sur iOS : Google + Apple côte à côte (50/50)
- [ ] Auth Google/Apple : même flow que téléphone après Firebase (getProfile → 200/404)
- [ ] Rôle préféré persisté dans Hive après registration
- [ ] Utilisateur existant (retour dans l'app) : ne voit ni `RoleScreen` ni `OnboardingScreen`
- [ ] `HomeScreen` inchangé
- [ ] Tous les tests passent (`flutter test`)
- [ ] Couverture ≥ 90 %

---

## 9. Ce qui est hors scope

- Modification du HomeScreen (map, contenu)
- Modification du design de `PinSetupScreen` (déjà bien)
- Modification du design de `LocalAuthScreen`
- Onboarding multi-slides / carrousel
- Profil complet (prénom, nom) dans le flow — à faire dans un écran dédié post-inscription
