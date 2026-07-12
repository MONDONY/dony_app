# Spec : Profil public — hero plat, bouton compact, signalement
**Date :** 2026-07-11 | **Status :** ✅ Approuvé

---

## Contexte

`ProfilePublicScreen` (`lib/features/profile/presentation/screens/profile_public_screen.dart`) affiche le profil d'un utilisateur consulté par un autre. Deux problèmes identifiés à partir de maquettes comparées en cours de brainstorming (style BlaBlaCar/TikTok) :

1. Le hero band (`_HeroBand`, L353) est un bandeau bleu plein écran (gradient `DonyColors.blue500 → #3F73F2`) qui alourdit l'écran, et le bouton d'abonnement est dans une `_StickySubscribeBar` (L150) fixée en bas — hors du flux naturel de scroll, pleine largeur.
2. Aucun moyen de signaler l'utilisateur consulté depuis son profil, alors que l'infra existe déjà : backend `ReportTargetType.USER` (`dony-back/src/main/java/com/dony/api/signalements/ReportTargetType.java`) + endpoint générique `POST /reports`, et côté Flutter `IncidentReportCubit`/`IncidentReportRepository` (`lib/features/incident_report/`) qui les enveloppe déjà avec `IncidentTargetType.user`.

**Hors scope (confirmé pendant le brainstorming, ne pas toucher) :**
- Sections À propos / Langues / Transport / Badges / Disponibilité (`_AboutSection`, `_TravelerInfoSection`, `_BadgesSection`, `_ContactInfoSection`) — structure et contenu inchangés, seul le style de conteneur change (voir §2).
- `_RecentReviewsSection` — déjà plafonnée à 3 avis + lien "Voir tous les avis (N) ›" ouvrant `AllReviewsBottomSheet` (L1024-1047). Rien à changer ici.
- Un système de messagerie profil-à-profil sans lien avec un `bid` **n'existe pas** (`ConversationOpenBloc`/`ConversationOpenRequested` est strictement scopé à un `bidId`, pas de `userId`). On ne rajoute donc **pas** de tuile "Contacter" générique dans cette itération — seul le signalement est ajouté.

---

## 1. Suppression du bandeau + `_StickySubscribeBar`

- `_HeroBand` : retirer le `Container` à `gradient`. Le hero devient un bloc à fond transparent (hérite de `Theme.of(context).scaffoldBackgroundColor`), centré, padding réduit (`DonySpacing.base` top au lieu de `DonySpacing.lg`).
- `_StickySubscribeBar` et son usage dans le `Scaffold.body` (`Column([Expanded(body), _StickySubscribeBar()])`, L134-140) : **supprimés**. Quand `showButton` est vrai, le bouton d'abonnement est rendu **dans** le hero (voir §2), plus en dehors du scroll.
- `DonyAppBar` : garder tel quel (compact, `title: appBarTitle`, divider bottom) — c'est déjà le widget qui reste fixe pendant le scroll (il n'est pas dans le `CustomScrollView`). Rien à changer sur ce point, juste ajouter `actions` (voir §3).

---

## 2. Hero plat + bouton pilule compact

### Structure (remplace `_HeroBand`)

```
Column (centré, crossAxisAlignment.center)
├── _HeroAvatar (inchangé : 64px, anneau, badge ✓ vérifié en coin)
├── displayName (headlineLarge, w800, couleur onSurface — plus blanc)
├── Wrap des pills Vérifié/PRO/Kilo Pro (inchangé, juste recoloré : fond cs.primaryContainer / texte cs.primary au lieu de blanc translucide)
├── metaLine "⭐ note · N avis · membre depuis" (bodySmall, onSurfaceVariant)
├── SizedBox(DonySpacing.base)
└── si showButton : _SubscribeAction (nouveau widget, voir ci-dessous)
```

### Bouton d'abonnement — réutilise `DonyButton(fullWidth: false)`, pattern déjà en prod

Pas besoin de nouveau composant : `DonyButton` supporte déjà `fullWidth: false` (contenu centré, pas de largeur imposée). Un widget quasi-identique à ce qu'on veut existe déjà : `_SubscribedRow` dans `lib/features/subscriptions/presentation/traveler_profile_hub_screen.dart:461-511`, qui combine `DonyButton(fullWidth:false)` + `IconButton` cloche branché sur `TogglePushPressed`. On reprend exactement ce pattern, réécrit pour consommer `TravelerSubscribeBloc` (au lieu de `TravelerHubBloc` utilisé par l'écran hub) :

- **Non abonné** : `DonyButton(label: "S'abonner", iconAsset: 'bell', fullWidth: false, isLoading: ..., onPressed: () => bloc.add(const SubscribePressed()))`.
- **Abonné** : `DonyButton(label: 'Abonné ✓', variant: secondary, fullWidth: false, onPressed: () => _confirmUnsubscribe(context))` + `SizedBox(width: DonySpacing.sm)` + `IconButton` cloche **interactive** :
  ```dart
  IconButton(
    tooltip: pushEnabled ? 'Désactiver les notifications' : 'Activer les notifications',
    icon: DonyIcon(pushEnabled ? 'bell' : 'bell-off', color: cs.primary),
    onPressed: () => context.read<TravelerSubscribeBloc>().add(TogglePushPressed(!pushEnabled)),
  )
  ```
  Le state `TravelerSubscribeState.pushEnabled` (déjà présent, `traveler_subscribe_state.dart:6`) alimente l'icône `bell`/`bell-off` exactement comme dans `_SubscribedRow`. **La cloche est donc interactive** (toggle notifications), pas décorative — correction par rapport à une première hypothèse écartée après lecture du bloc.
- Confirmation de désabonnement : réutiliser `DonyDialog.show(title: 'Se désabonner ?', message: 'Vous ne recevrez plus les notifications de ce voyageur.', confirmLabel: 'Se désabonner', variant: destructive, iconAsset: 'bell-off')` comme dans `_confirmUnsubscribe` (`traveler_profile_hub_screen.dart:466-481`), puis `context.read<TravelerSubscribeBloc>().add(const UnsubscribePressed())`.
- `isLoading` réutilise `state.status == loading/initial` comme aujourd'hui.
- Le tout centré horizontalement dans le hero via un `Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center)` — pas de `Expanded`, contrairement au hub bar qui est pleine largeur en bas d'écran.

### Stats row (`_StatsRow`, L591)

Retirer la colonne "Répond en" (`profile.responseDelayHours`, jamais alimenté en prod → toujours "—"). Ne reste que **Note** et **Livraisons**, séparées par un seul `VerticalDivider` (au lieu de deux). Le reste (`_StatItem`) est inchangé.

### `_FlatSection` (L322)

Inchangé — c'est déjà le wrapper "filet + padding, pas de card" utilisé pour à propos / langues / badges / disponibilité / avis. On ne touche pas ces sections.

---

## 3. Signalement — menu ⋮ dans la navbar

- `DonyAppBar(title: appBarTitle, actions: [...])` : ajouter une action, **uniquement si `!isOwnProfile`** :

```dart
actions: isOwnProfile ? null : [
  IconButton(
    tooltip: 'Signaler',
    icon: DonyIcon('flag', color: cs.onSurfaceVariant),
    onPressed: () => context.push(
      '/settings/report-incident',
      extra: {'targetType': IncidentTargetType.user, 'targetId': viewedUserId},
    ),
  ),
],
```

- **Pas de sheet custom** — l'écran `IncidentReportScreen` (`lib/features/incident_report/presentation/screens/incident_report_screen.dart`) existe déjà, avec motif (`incidentReasons`), description, photos optionnelles, et accepte déjà `targetType`/`targetId` en constructeur. Son commentaire de tête anticipe littéralement ce cas : *"les points d'entrée contextuels (profil utilisateur, colis…) passent leur cible"*. Seul manque le branchement du `state.extra` sur la route — la route `/settings/report-incident` (`router.dart:1080-1089`) construit aujourd'hui `const IncidentReportScreen()` sans lire `state.extra`.
- **Modification nécessaire dans `router.dart`** : lire `state.extra as Map<String, dynamic>?` (convention déjà utilisée ailleurs dans ce fichier, ex. L398/L681/L868) pour extraire `targetType`/`targetId`, défaut `IncidentTargetType.app`/`null` si absent (comportement actuel préservé pour l'entrée réglages) :
  ```dart
  GoRoute(
    path: 'report-incident',
    builder: (context, state) {
      final extra = state.extra as Map<String, dynamic>?;
      final targetType = extra?['targetType'] as IncidentTargetType? ?? IncidentTargetType.app;
      final targetId = extra?['targetId'] as String?;
      return MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => getIt<IncidentReportCubit>()),
          BlocProvider(create: (_) => getIt<IncidentPhotosCubit>()),
        ],
        child: IncidentReportScreen(targetType: targetType, targetId: targetId),
      );
    },
  ),
  ```
- `IncidentReportCubit`/`IncidentPhotosCubit` sont fournis par cette route elle-même — rien à ajouter côté DI pour `/profile/public`.
- **Analytics** : `IncidentReportCubit.submit` déclenche déjà `AnalyticsEvents.incidentReported` (`{'target_type': 'USER', 'photo_count': N}`) — rien à ajouter côté events.

---

## 4. Ce qui NE change PAS

- `ProfilePublicBloc` / `TravelerSubscribeBloc` — logique inchangée, seul le style des widgets qui les consomment change.
- `_AboutSection`, `_TravelerInfoSection`, `_BadgesSection`, `_ContactInfoSection`, `_RecentReviewsSection` — inchangées (contenu et plafonnement des avis déjà corrects).
- Animations stagger existantes (`fadeIn` + délais croissants par section) — conservées.
- Le comportement de scroll : `DonyAppBar` reste fixe (hors `CustomScrollView`), tout le reste défile — comportement déjà correct aujourd'hui, aucune régression à corriger, juste confirmé par les maquettes.

---

## 5. Tests à ajouter / adapter

**`test/features/profile/presentation/screens/profile_public_screen_test.dart`** (créer si absent, sinon étendre) :

| Test | Description |
|------|-------------|
| hero sans gradient | Le hero ne contient plus de `Container` à `gradient` bleu |
| pas de sticky bar | `_StickySubscribeBar` absent du widget tree même si `showSubscribe: true` |
| bouton compact non abonné | `state.subscribed == false` → pilule "S'abonner" pleine largeur **absente**, largeur intrinsèque |
| bouton + cloche abonné | `state.subscribed == true` → label "Abonné ✓" + icône cloche visible à côté, séparée |
| cloche toggle | Tap cloche → `TogglePushPressed(!pushEnabled)` ajouté au bloc ; icône passe `bell` ↔ `bell-off` selon `state.pushEnabled` |
| stats 2 colonnes | "Répond en" absent, seuls "Note" et "Livraisons" présents |
| action ⋮ absente sur son propre profil | `isOwnProfile == true` → pas d'icône flag dans les actions |
| action ⋮ présente + navigue | `isOwnProfile == false` → icône flag présente, tap → `context.push('/settings/report-incident', extra: {...})` avec `targetType: IncidentTargetType.user`, `targetId: viewedUserId` |
| avis inchangés | Toujours plafonnés à 3 + lien "Voir tous les avis (N)" si `ratingCount > 0` |

Couverture ≥ 90 % sur le fichier modifié (règle projet).

---

## 6. Checklist d'implémentation

- [ ] `_HeroBand` : gradient bleu retiré, fond transparent, contenu centré
- [ ] `_StickySubscribeBar` + son usage dans `Scaffold.body` supprimés
- [ ] Bouton d'abonnement réécrit avec `DonyButton(fullWidth: false)` (pattern repris de `_SubscribedRow`, `traveler_profile_hub_screen.dart:461-511`) + cloche interactive branchée sur `TogglePushPressed`
- [ ] `_StatsRow` : colonne "Répond en" retirée, 2 colonnes restantes
- [ ] `DonyAppBar.actions` : icône flag ajoutée si `!isOwnProfile`, navigue vers `/settings/report-incident`
- [ ] `router.dart` : route `report-incident` lit `state.extra` pour `targetType`/`targetId` (défaut `app`/`null` préservé)
- [ ] Sections À propos/Langues/Transport/Badges/Disponibilité/Avis non modifiées (vérifier non-régression visuelle)
- [ ] Tous les tests passent (`flutter test`)
- [ ] Couverture ≥ 90 %
