# Refonte visuelle du chat façon WhatsApp (messages + support)

Date : 2026-10-24. Origine : retour testeur Sentry FLUTTER-S0 (build 148, iPhone, thème sombre) : « je veux un chat de type WhatsApp, pareil pour la messagerie ». Précisé par le propriétaire.

## Intention
Le testeur ne trouve pas l'icône pour envoyer une image et n'aime pas le design du chat. Aujourd'hui l'envoi de photo passe par un trombone (`Icons.attach_file_rounded`) peu lisible, grisé à 40 % quand les photos ne sont pas permises, puis par une feuille « appareil photo / galerie ». Le but : un chat qui se lit et se manie comme WhatsApp, où l'ajout d'une photo se voit tout de suite.

## Périmètre
Dans : le fil de chat des messages (`lib/features/messaging/presentation/chat_screen.dart`, `_InputBar`, `_MessageBubble`, `_DateSeparator`, `ChatAttachButton` dans `widgets/chat_photo.dart`) et le fil d'un ticket de support (`lib/features/support/presentation/screens/support_ticket_detail_screen.dart`, `_MessageComposer`, `_MessageBubble`, `widgets/support_attachment_picker.dart`).

Hors périmètre (décision explicite du propriétaire) : liste des conversations, accueil du support, fils de négociation (`bid_negotiation_thread_screen`, `negotiation_thread_screen`), assistant IA, bulles de `ai_form_draft`.

## Objectifs
- Barre de saisie style WhatsApp : pilule arrondie, « + » à gauche, champ « Message », icône appareil photo à l'intérieur à droite, bouton rond d'envoi à droite.
- Bulles style WhatsApp, version « couleurs Yadony » (choix B) : mes messages à droite en couleur de marque (`ColorScheme.primary`), texte `onPrimary`, heure et coches dans la bulle ; messages de l'autre à gauche, fond blanc/surface avec contour fin ; photos aux coins arrondis ; fond du fil clair neutre ; séparateurs de date en pastille.
- Même rendu sur le chat et le support, via des composants partagés.
- Thèmes clair ET sombre corrects (le testeur est en sombre).

## Hors objectifs, et à éviter
- Pas de message vocal (le back ne le gère pas) : donc pas de bouton micro, seulement l'envoi.
- Aucune logique métier changée : réponse par glissement, citations, édition, suppression, purge J+3, bandeau de rétention, règles `chatAttachStateFor`, quota de 4 images du support, état « ticket résolu », envoi optimiste, tout reste.
- Pas de nouvel écran ni de nouvelle route.
- Anti-objectif : un joli chat qui casse l'envoi de photo, la lecture seule, ou l'accessibilité (cibles ≥ 44 pt, libellés Semantics, texte agrandi).

## Contraintes du dépôt
Pas de `setState` (BLoC), le « + » ouvre le choix photo via `DonyBottomSheet` avec boutons dans `stickyBottom`, pas de texte en dur (ARB fr + en, `flutter gen-l10n`), analytics via `AnalyticsEvents` + table du CLAUDE.md si un événement est ajouté, pas de code mort (supprimer l'ancien trombone et l'ancien composeur du support une fois remplacés), tests : widget tests des états (actif, grisé, masqué, envoi en cours, désactivé, thème clair et sombre), a11y, couverture ≥ 90 % sur le code touché. Branche `feature/...`, worktree dédié, PR app seule (aucun changement back, aucune fiche assistant à mettre à jour sauf si une fiche décrit l'icône trombone : à vérifier).

## Décisions prises
- Style B retenu (couleurs Yadony) ; maquette : propositions A/B/C montrées, B choisi.
- « + » à gauche ouvre le choix appareil photo / galerie ; appareil photo en raccourci à l'intérieur du champ à droite.
- Même style pour le support que pour le chat (bulles et barre).

## Mes choix (à confirmer par le propriétaire)
- Composeur et bulles partagés entre messaging et support (un seul widget), pour ne pas maintenir deux copies.
- Quand les photos ne sont pas permises : « + » et appareil photo restent visibles, grisés, le tap explique pourquoi (comportement actuel du trombone conservé). Masqués seulement si le chat est en lecture seule ou sans avenir pour une photo.
- Couleur de marque = `ColorScheme.primary` du thème (pas le bleu de la maquette, qui n'était qu'un placeholder).
- Au support, les vignettes en attente restent au-dessus du champ.

- Thèmes : le fond du fil et les bulles de l'autre suivent le thème (surface claire en clair, surface sombre en sombre). « Clair neutre » de la maquette ne veut pas dire un fil clair dans une app sombre.
- Partage : on partage l'enveloppe visuelle (couleurs, rayons, heure, coches, photos) et la barre de saisie. Le contenu propre à chaque écran reste en emplacements : citations, « modifié », « supprimé », étiquettes d'agent du support, grille d'images du support.
- Barre de saisie partagée : emplacement pour les vignettes en attente au-dessus du champ (support) ; « + » ajoute une photo à la fois dans les deux écrans (comportement actuel conservé) et se grise au quota de 4 du support ; l'envoi reste actif avec images sans texte, selon la règle actuelle de chaque écran (`canSendWith` au support).
- L'appareil photo à l'intérieur du champ disparaît dès qu'un texte est saisi, comme sur WhatsApp ; le bouton d'envoi prend alors la place.
- Quand les photos ne sont pas permises, le tap sur « + » ou l'appareil photo réutilise l'explication actuelle du trombone (`_onAttachLocked`).
- Ces choix sont considérés acceptés tant que le propriétaire ne les conteste pas à la lecture du document.

## Laissé au constructeur
Dimensions exactes, rayons, espacements, animations (respecter `disableAnimations`), emplacement du composant partagé, nom des widgets, découpage des tests.
