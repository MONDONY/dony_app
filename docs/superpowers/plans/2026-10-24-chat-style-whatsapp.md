# Chat façon WhatsApp (messages + support) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Donner au fil de messages et au fil d'un ticket de support la même barre de saisie (« + », appareil photo, envoi) et les mêmes bulles que WhatsApp, aux couleurs du thème.

**Architecture:** Trois composants partagés dans `lib/core/design/widgets/` : `DonyChatBubbleShell` (enveloppe d'une bulle), `DonyChatDateSeparator` (pastille de date) et `DonyChatComposer` (barre de saisie). Le chat et le support les utilisent ; le contenu propre à chaque écran reste fourni par l'écran. Aucun changement de logique métier, de BLoC ni de back.

**Tech Stack:** Flutter, flutter_bloc, `DonyBottomSheet`, `image_picker` via `DonyMediaService`, l10n ARB fr/en.

**Spec:** `docs/superpowers/specs/2026-10-24-chat-style-whatsapp-design.md` (copié depuis le scratchpad à la tâche 1).

## Global Constraints

- Aucun `setState` : l'état vit dans le BLoC ou dans un `ValueListenableBuilder` sur le contrôleur.
- Aucun texte en dur : clés ARB fr + en, `context.l10n`, puis `flutter gen-l10n`. Garde-fou `dart run tool/check_hardcoded_strings.dart` à 0.
- Aucun dégradé, couleurs unies (couleurs du `ColorScheme`, jamais de `0xFFFFFFFF` en fond).
- Cibles tactiles ≥ 44 pt, `Semantics` sur toute icône seule, `fontSize` ≥ 12 hors horodatage existant (10).
- Animations 150–300 ms `easeOutCubic`, durée 0 si `MediaQuery.disableAnimationsOf`.
- Thèmes clair ET sombre testés.
- Pas de code mort : supprimer `ChatAttachButton`, l'ancien `_InputBar` enabled, l'ancien `_MessageComposer` du support et tout ce qui n'a plus d'appelant (grep avant), ainsi que leurs tests dédiés.
- Aucun nouvel événement analytics (comportement inchangé) ; `message_sent`, `support_ticket_message_sent`, `support_attachment_added` restent émis par leurs BLoC.
- Branche `feature/chat-style-whatsapp`, worktree `dony_app-worktrees/chat-style-whatsapp`. Commits sans `Co-Authored-By`, terminés par `Claude-Session: https://claude.ai/code/session_01PPmjPQj5kWbA2UymjUB1pi`. Aucun build.
- Tests avec police Ahem (12 px par caractère) et `flutter test --no-pub`.

## Review Focus

- Texte très long ou multiligne : le champ grandit jusqu'à 132 px puis défile, le bouton d'envoi reste visible. Test dans la tâche 2.
- Texte agrandi à 200 % : aucune erreur de débordement, cibles ≥ 44 pt. Test dans la tâche 2.
- Thème sombre : bulle de l'autre lisible (contraste texte/fond ≥ 4,5:1). Test dans la tâche 1.
- Double tap sur Envoyer pendant `sending` : un seul envoi. Test dans la tâche 2.
- Support : 4 images en attente grisent « + » ; images prêtes sans texte activent l'envoi ; image en cours d'envoi le désactive (`SupportState.canSendWith`). Tests dans la tâche 4.
- Support : message sans `createdAt` : pas d'heure affichée, pas de plantage. Test dans la tâche 4.
- Chat : photos grisées (« locked ») : le tap sur « + » ou sur l'appareil photo ouvre l'explication, jamais la caméra. Test dans la tâche 3.

---

### Task 1: Bulle et séparateur de date partagés

**Files:**
- Create: `docs/superpowers/specs/2026-10-24-chat-style-whatsapp-design.md` (copie du spec), `docs/superpowers/plans/2026-10-24-chat-style-whatsapp.md` (copie de ce plan)
- Create: `lib/core/design/widgets/dony_chat_bubble.dart`, `lib/core/design/widgets/dony_chat_date_separator.dart`
- Modify: `lib/core/design/design_system.dart` (exports, si le fichier liste les widgets)
- Test: `test/core/design/widgets/dony_chat_bubble_test.dart`, `test/core/design/widgets/dony_chat_date_separator_test.dart`

**Interfaces:**
- Produces:
  - `DonyChatBubbleShell({Key? key, required bool isMe, required Widget child, bool tail = true, Widget? meta})` : conteneur de bulle. Moi : `cs.primary`, texte à fournir en `cs.onPrimary` par l'appelant. L'autre : `cs.surface` avec `Border.all(color: cs.outlineVariant)`, sans ombre. Rayon `DonyRadius.card`, coin « queue » `DonyRadius.xs` en bas (droite si `isMe`, gauche sinon) quand `tail` est vrai. `meta` est rendu sous `child`, aligné à droite, dans la bulle, avec 10 pt de marge horizontale et 6 pt en bas.
  - `DonyChatDateSeparator({Key? key, required DateTime date})` : pastille identique à l'actuel `_DateSeparator` (`chat_screen.dart:1700`), libellés `commonDateToday` / `commonDateYesterday` / `DateFormat.yMMMMd`.
  - `DonyChatMeta` n'existe pas : l'appelant construit son `meta`.

- [ ] **Step 1: Créer le worktree et copier les documents** depuis le dépôt principal : `git worktree add dony_app-worktrees/chat-style-whatsapp -b feature/chat-style-whatsapp origin/main`, copier `.dart_tool`/secrets selon la mémoire « Worktree neuf » (`env.*.json`, `GoogleService-Info.plist`, `google-services.json`), `flutter pub get --offline`, copier le spec et ce plan dans `docs/superpowers/`.
- [ ] **Step 2: Écrire les tests (rouges)** `dony_chat_bubble_test.dart` : (a) `isMe: true` → `Container` de couleur `cs.primary`, sans bordure ; (b) `isMe: false` → couleur `cs.surface`, bordure `cs.outlineVariant`, `boxShadow` nul ; (c) `tail: true` met `DonyRadius.xs` en bas à droite si `isMe`, en bas à gauche sinon, `tail: false` met `DonyRadius.card` partout ; (d) `meta` est affiché sous le contenu ; (e) en thème sombre, le contraste `cs.onSurface` sur `cs.surface` ≥ 4,5 (calculer avec `computeLuminance`). `dony_chat_date_separator_test.dart` : « Aujourd'hui », « Hier » et une date longue, en fr.
- [ ] **Step 3: Lancer** `flutter test --no-pub test/core/design/widgets/dony_chat_bubble_test.dart test/core/design/widgets/dony_chat_date_separator_test.dart` ; attendu : échec (fichiers absents).
- [ ] **Step 4: Implémenter** les deux widgets d'après les signatures ci-dessus ; reprendre le corps de `_DateSeparator` sans changer son rendu.
- [ ] **Step 5: Relancer** les mêmes tests ; attendu : tous verts.
- [ ] **Step 6: Commit** `feat(chat): bulle et séparateur de date partagés`.

### Task 2: Barre de saisie partagée

**Files:**
- Create: `lib/core/design/widgets/dony_chat_composer.dart`
- Test: `test/core/design/widgets/dony_chat_composer_test.dart`

**Interfaces:**
- Consumes: clés ARB existantes `chatAttachPhotoTooltip`, `chatPhotoLockedSemantics`, `commonTakePhoto`, `chatSendMessageSemantics`.
- Produces:
  - `DonyComposerAttach({required VoidCallback onPlus, required VoidCallback onCamera, required VoidCallback onLocked, bool locked = false})`. `null` à la place d'un `DonyComposerAttach` = ni « + » ni appareil photo.
  - `DonyChatComposer({Key? key, required TextEditingController controller, required String hintText, required VoidCallback onSend, required bool Function(String draft) canSend, FocusNode? focusNode, bool sending = false, DonyComposerAttach? attach, Widget? above, int? maxLength, bool showTopBorder = true})`.
  - Clés : `chat-attach-button` (« + », conservée pour limiter le churn des tests), `chat-camera-button`, `chat-send-button`.

Comportement : pilule `scaffoldBackgroundColor` + bordure `outlineVariant`, `maxHeight: 132`, champ multiligne ; « + » à gauche (38 pt de visuel, zone ≥ 44), appareil photo à l'intérieur à droite, visible seulement si `attach != null` et `controller.text.trim().isEmpty` ; bouton rond d'envoi `cs.primary` (grisé `outlineVariant` si `!canSend(text)`), remplacé par un `CircularProgressIndicator` 22 pt quand `sending`. `locked` : « + » et appareil photo à 40 % d'opacité, leur tap appelle `onLocked`, jamais `onPlus`/`onCamera`. `above` est placé au-dessus de la pilule (vignettes du support). Bas = `MediaQuery.viewInsetsOf(context).bottom` animé 160 ms. Rien en `setState` : `ValueListenableBuilder<TextEditingValue>` sur le contrôleur.

- [ ] **Step 1: Écrire les tests (rouges)** : (a) champ vide + `attach` → « + » et appareil photo présents, envoi grisé ; (b) texte saisi → appareil photo absent, envoi actif, tap appelle `onSend` ; (c) `sending: true` → spinner à la place de l'envoi, deux taps rapides = 0 appel de `onSend` ; (d) `locked: true` → tap sur « + » et sur l'appareil photo appellent `onLocked` seulement ; (e) `attach: null` → ni « + » ni appareil photo ; (f) `above` rendu au-dessus ; (g) `canSend` reçoit le texte courant (retourne vrai avec 0 texte quand l'appelant le décide : cas support avec images) ; (h) texte de 400 caractères → hauteur ≤ 132 + marges, envoi visible ; (i) `MediaQuery(textScaler: TextScaler.linear(2))` → aucune exception de débordement et chaque bouton ≥ 44 × 44 ; (j) thèmes clair et sombre sans exception ; (k) `Semantics` : libellés `chatAttachPhotoTooltip`, `commonTakePhoto`, `chatSendMessageSemantics`, `chatPhotoLockedSemantics` selon l'état.
- [ ] **Step 2: Lancer** `flutter test --no-pub test/core/design/widgets/dony_chat_composer_test.dart` ; attendu : échec.
- [ ] **Step 3: Implémenter** `DonyChatComposer` d'après les signatures ; reprendre les mesures de l'actuel `_InputBar` (`chat_screen.dart:2825`) pour la pilule, le `TextField` et le bouton d'envoi ; l'envoi ne se déclenche que si `canSend(text) && !sending`.
- [ ] **Step 4: Relancer** ; attendu : tous verts.
- [ ] **Step 5: Commit** `feat(chat): barre de saisie partagée façon WhatsApp`.

### Task 3: Écran de chat des messages

**Files:**
- Modify: `lib/features/messaging/presentation/chat_screen.dart` (`_onAttachTapped` ~l.507, `_onAttachLocked` ~l.581, `_InputBar` ~l.2825, `_MessageBubble` ~l.1755, `_DateSeparator` ~l.1700), `lib/features/messaging/presentation/widgets/chat_photo.dart` (suppression de `ChatAttachButton`)
- Test: `test/features/messaging/presentation/chat_photo_test.dart`, `chat_screen_test.dart`, `chat_reply_test.dart`, `chat_edit_message_test.dart`, `chat_screen_actions_test.dart` (adapter les finders)

**Interfaces:**
- Consumes: `DonyChatComposer`, `DonyComposerAttach`, `DonyChatBubbleShell`, `DonyChatDateSeparator` (tâches 1-2) ; `chatAttachStateFor` et `ChatAttachState` inchangés.
- Produces: `_ChatScreenState._onPlusTapped()` (ouvre la feuille galerie/appareil photo existante puis `_sendPhotoFrom`), `_ChatScreenState._onCameraTapped()` (appelle `_sendPhotoFrom(ImageSource.camera)` directement), `Future<void> _sendPhotoFrom(ImageSource source)` (pick → `_previewPhoto` → `ChatImageSendRequested`, corps repris de l'actuel `_onAttachTapped` après le choix de la source).

- [ ] **Step 1: Adapter/écrire les tests (rouges)** dans `chat_photo_test.dart` : (a) `ChatAttachState.enabled` → tap sur `chat-attach-button` ouvre la feuille (clés `chat-photo-source-camera`/`chat-photo-source-gallery`) ; (b) tap sur `chat-camera-button` appelle `pickPhotoOverride(ImageSource.camera)` sans feuille ; (c) `locked` → tap sur « + » et sur l'appareil photo ouvre `chat-photo-locked-message`, `pickPhotoOverride` jamais appelé ; (d) `hidden` → aucun des deux boutons ; (e) texte saisi → `chat-camera-button` absent. Dans `chat_screen_test.dart` : bulle envoyée = `cs.primary`, bulle reçue = `cs.surface` + contour, heure dans la bulle (`DonyChatBubbleShell.meta`), séparateurs de date présents, tout en clair et en sombre.
- [ ] **Step 2: Lancer** `flutter test --no-pub test/features/messaging/presentation` ; attendu : échecs sur les nouveaux finders.
- [ ] **Step 3: Remplacer** dans `_InputBar` la branche enabled par `DonyChatComposer` (hintText `l.chatMessageHint`, `maxLength: ChatMessageRules.maxLength`, `canSend: (d) => d.trim().isNotEmpty && !isSending`, `attach` construit depuis `attachState` : `hidden` → `null`, `locked` → `locked: true`) ; garder la branche `disabled` (verrou) telle quelle ; scinder `_onAttachTapped` en `_onPlusTapped`/`_sendPhotoFrom`. Remplacer le conteneur de `_MessageBubble` par `DonyChatBubbleShell` (`meta` = ligne « modifié » + heure + coches existante, couleur `cs.onPrimary` à 70 % sur ma bulle, coche lue en `cs.onPrimary`), et `_DateSeparator` par `DonyChatDateSeparator`. Supprimer `ChatAttachButton` et `_DateSeparator`, puis grep pour confirmer zéro appelant.
- [ ] **Step 4: Relancer** les tests du dossier ; attendu : verts (réponse par glissement, édition, suppression, signalement, photos inchangés).
- [ ] **Step 5: Commit** `feat(chat): saisie et bulles façon WhatsApp sur les messages`.

### Task 4: Fil de ticket du support

**Files:**
- Modify: `lib/features/support/presentation/screens/support_ticket_detail_screen.dart` (`_TicketThread`, `_MessageBubble` ~l.180, `_MessageComposer` ~l.522), `lib/features/support/presentation/widgets/support_attachment_picker.dart`
- Test: `test/features/support/presentation/support_ticket_detail_screen_test.dart`, `test/features/support/presentation/widgets/support_attachment_picker_test.dart`, `support_ticket_detail_flow_test.dart`

**Interfaces:**
- Consumes: composants des tâches 1-2 ; `SupportState.canSendWith(String)`, `pendingAttachments`, `SupportAttachmentPickRequested`, `SupportMessageSendRequested`.
- Produces: dans `support_attachment_picker.dart`, `SupportAttachmentStrip` (rangée de vignettes seule, `SizedBox.shrink()` quand aucune image ; remplace la partie vignettes de `SupportAttachmentPicker`) et `class SupportAttachmentActions { static Future<void> pick(BuildContext context, ImageSource source); static void showSourceSheet(BuildContext context); static const int max = 4; }` (corps repris de `_pick` et `_showSourceSheet` actuels).

- [ ] **Step 1: Écrire/adapter les tests (rouges)** : (a) fil résolu → aucun composeur ; (b) « + » ouvre la feuille source, appareil photo appelle `SupportAttachmentActions.pick(camera)` via `DonyMediaService` mocké ; (c) 4 images en attente → « + » et appareil photo grisés, `onLocked` n'est pas proposé (tap sans effet) ; (d) images prêtes sans texte → envoi actif ; image `uploading` → envoi désactivé ; (e) `sending` → spinner ; (f) message sans `createdAt` → pas d'heure, pas d'exception ; (g) message avec `createdAt` → heure dans la bulle ; (h) bulle de l'utilisateur `cs.primary`, bulle du support `cs.surface` avec contour et étiquette `supportBrandName` ; (i) séparateurs de date entre jours différents ; (j) clair et sombre.
- [ ] **Step 2: Lancer** `flutter test --no-pub test/features/support/presentation` ; attendu : échecs.
- [ ] **Step 3: Implémenter** : `_MessageComposer` devient un `StatelessWidget` qui rend `DonyChatComposer` avec `canSend: (d) => state.canSendWith(d) && !sending`, `above: const SupportAttachmentStrip()`, `attach` (`locked`/grisé quand `pendingAttachments.length >= SupportAttachmentActions.max`, `onPlus: showSourceSheet`, `onCamera: pick(camera)`), `onSend` qui émet `SupportMessageSendRequested(ticketId, content: controller.text.trim())` ; supprimer le `setState` et `_draft`. `_MessageBubble` utilise `DonyChatBubbleShell` (étiquette agent et grille d'images en contenu, `meta` = heure si `createdAt != null`). Ajouter `DonyChatDateSeparator` quand le jour change d'un message au suivant (liste construite en `itemBuilder`). Supprimer l'ancien trombone du picker, puis grep ; supprimer la clé ARB `supportAttachTooltip` (fr + en, `flutter gen-l10n`) uniquement si plus aucun appelant.
- [ ] **Step 4: Relancer** ; attendu : verts.
- [ ] **Step 5: Commit** `feat(support): saisie et bulles façon WhatsApp sur le fil de ticket`.

### Task 5: Vérifications et PR

**Files:**
- Modify: aucun fichier de code ; PR sur MONDONY/dony_app.

- [ ] **Step 1:** `flutter analyze` (attendu : aucun problème), `dart format --set-exit-if-changed lib test`, `dart run tool/check_hardcoded_strings.dart` (attendu : 0).
- [ ] **Step 2:** `flutter test --no-pub test/core/design test/features/messaging test/features/support test/a11y` (attendu : tout vert).
- [ ] **Step 3:** vérifier qu'aucune fiche de l'assistant ne décrit le trombone : `grep -ril "trombone\|paperclip" ../dony-back/src/main/resources/assistant/kb` ; si une fiche le cite, la corriger en fr ET en en dans une PR back jumelle, fusionnée avant celle-ci.
- [ ] **Step 4:** pousser la branche, ouvrir la PR (description en français : problème du testeur, avant/après, aucun changement de logique, aucun build, session en dernière ligne), attendre la CI verte (4 shards, analyze, APK debug), fusionner `gh pr merge <n> --squash --repo MONDONY/dony_app`, puis nettoyer worktree et branche locale selon la règle du CLAUDE.md.
- [ ] **Step 5:** passer `FLUTTER-S0` en résolu dans Sentry avec un commentaire citant la PR ; ne rien builder ni déployer sans go.
