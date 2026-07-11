# Spec : Profil public — hero plat, bouton compact, signalement
**Date :** 2026-07-11 | **Status :** ✅ Approuvé

---

## Contexte

`ProfilePublicScreen` (`lib/features/profile/presentation/screens/profile_public_screen.dart`) affiche le profil d'un utilisateur consulté par un autre. Deux problèmes identifiés à partir de maquettes comparées en cours de brainstorming (style BlaBlaCar/TikTok) :

1. Le hero band (`_HeroBand`, L353) est un bandeau bleu plein écran (gradient `DonyColors.blue500 → #3F73F2`) qui alourdit l'écran, et le bouton d'abonnement est dans une `_StickySubscribeBar` (L150) fixée en bas — retirée du flux naturel, toujours pleine largeur (contrainte `DonyButton` : hauteur 52px, toujours pleine largeur).
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

### `_SubscribeAction` — nouveau widget, PAS `DonyButton`

`DonyButton` impose hauteur 52px + pleine largeur (règle du design system) — inadapté ici, le bouton doit être **compact, centré, largeur au contenu** (référence : bouton "Suivre" TikTok). Nouveau petit composant local à `profile_public_screen.dart` (pas dans `core/design/` — usage unique) :

```dart
class _SubscribePill extends StatelessWidget {
  final String label;
  final String iconAsset;
  final bool filled;      // true = fond cs.primary plein ; false = fond cs.primaryContainer
  final bool isLoading;
  final VoidCallback? onPressed;
}
```

- **Non abonné** : `filled: true` — fond `cs.primary` plein, texte blanc, icône `+`, label `"S'abonner"`. Hauteur 38px, `padding: EdgeInsets.symmetric(horizontal: 24)`, `borderRadius: DonyRadius.full`. `onPressed` → `SubscribePressed()` (inchangé).
- **Abonné** : `filled: false` — fond `cs.primaryContainer`, texte/icône `cs.primary`, icône check, label `"Abonné"`. `onPressed` → confirmation puis `UnsubscribePressed()` (comportement inchangé, juste le style qui change).
- À côté (row, `SizedBox(width: DonySpacing.sm)` entre les deux) : un second élément **rond, non interactif**, icône 🔔 (`DonyIcon('bell')`), visible **uniquement si `state.subscribed == true`** — indicateur visuel "tu recevras des notifications", pas un toggle séparé (le domaine `TravelerSubscribeBloc` n'a qu'un seul état abonné/non-abonné, pas de préférence de notification distincte — inventer ce concept serait hors scope).
- `isLoading` réutilise `state.status == loading/initial` comme aujourd'hui.

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
    onPressed: () => _showReportSheet(context, viewedUserId, profile.displayName),
  ),
],
```

- Pas de menu intermédiaire à options multiples (une seule action = pas besoin d'une liste, cf. retour "design pas simple" du brainstorming). Le tap ouvre **directement** la sheet de raisons, sur le modèle de `_showReportSheet` dans `traveler_options_sheet.dart` (L222-306) : handle, titre `"Signaler ${displayName}"`, sous-titre "Votre signalement sera traité par l'équipe Dony.", `RadioListTile` sur la même liste de raisons (`'Comportement inapproprié'`, `'Informations fausses'`, `'Tentative d'arnaque'`, `'Non-respect des délais'`, `'Autre'`), bouton `DonyButton(variant: destructive, label: 'Envoyer le signalement')` désactivé tant que rien n'est sélectionné.
- **Différence avec le pattern existant** : au lieu d'appeler un service de signalement lié à un `bid`, on appelle `IncidentReportCubit.submit(targetType: IncidentTargetType.user, targetId: viewedUserId, reason: selected!)`. Le cubit doit être disponible via `BlocProvider` sur cet écran (vérifier `injection.dart` : `IncidentReportCubit` est déjà `registerFactory` pour l'écran `incident_report` — l'enregistrer aussi ici, ou wrapper la sheet dans un `BlocProvider(create: (_) => getIt<IncidentReportCubit>())` local comme le fait `HandoverBottomSheet`/`EditProfileBottomSheet` pour un besoin ponctuel).
- Succès → `DonySnackbar.show(type: success, message: 'Signalement envoyé. Merci !')` + `context.pop()`. Erreur → `DonySnackbar.show(type: error, message: state.message)`.
- **Analytics** : `IncidentReportCubit.submit` déclenche déjà `AnalyticsEvents.incidentReported` (`{'target_type': 'USER', 'photo_count': 0}`) — rien à ajouter côté events, juste vérifier que ce event existe bien dans la table du `CLAUDE.md` (déjà le cas : `incident_report` feature existante) et l'y documenter s'il n'y est pas encore listé pour ce contexte précis (profil public).

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
| bouton + cloche abonné | `state.subscribed == true` → label "Abonné" + icône cloche visible à côté, séparée |
| stats 2 colonnes | "Répond en" absent, seuls "Note" et "Livraisons" présents |
| action ⋮ absente sur son propre profil | `isOwnProfile == true` → pas d'icône flag dans les actions |
| action ⋮ présente | `isOwnProfile == false` → icône flag présente, tap ouvre la sheet de signalement |
| signalement soumis | Sélection raison + tap "Envoyer" → `IncidentReportCubit.submit` appelé avec `targetType: user`, `targetId: viewedUserId` |
| avis inchangés | Toujours plafonnés à 3 + lien "Voir tous les avis (N)" si `ratingCount > 0` |

Couverture ≥ 90 % sur le fichier modifié (règle projet).

---

## 6. Checklist d'implémentation

- [ ] `_HeroBand` : gradient bleu retiré, fond transparent, contenu centré
- [ ] `_StickySubscribeBar` + son usage dans `Scaffold.body` supprimés
- [ ] Nouveau widget `_SubscribePill` (compact, non-`DonyButton`) + variante "abonné" avec cloche séparée non-interactive
- [ ] `_StatsRow` : colonne "Répond en" retirée, 2 colonnes restantes
- [ ] `DonyAppBar.actions` : icône flag ajoutée si `!isOwnProfile`, ouvre directement la sheet de raisons (pas de menu intermédiaire)
- [ ] Sheet de signalement branchée sur `IncidentReportCubit.submit(targetType: IncidentTargetType.user, ...)`
- [ ] `IncidentReportCubit` disponible sur l'écran (DI ou `BlocProvider` local à la sheet)
- [ ] Sections À propos/Langues/Transport/Badges/Disponibilité/Avis non modifiées (vérifier non-régression visuelle)
- [ ] Tous les tests passent (`flutter test`)
- [ ] Couverture ≥ 90 %
- [ ] Table des events `CLAUDE.md` : vérifier/documenter `incident_report_submitted` (ou event existant) pour le contexte "profil public"
