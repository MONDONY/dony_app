# Redesign de l'écran d'onboarding

## Contexte

L'écran d'onboarding actuel (`lib/features/auth/presentation/screens/onboarding_screen.dart`) est un écran unique scrollable : mascotte `DonyMascotteAnimated` (160dp) alignée en haut à gauche, logo, titre/tagline, sous-titre, puis 3 cartes avantages (`_FeatureCard` custom : Vérifié/Tracé/Garanti) empilées, CTA "Commencer" sticky en bas hors scroll.

Problèmes remontés :
1. Écran perçu comme peu clair.
2. Mascotte pas mise en avant (petite, coincée en haut à gauche, sous le fold visuel).
3. L'utilisateur ne prend pas conscience des avantages de Yadony (cartes en bas de scroll, potentiellement jamais vues).

## Décisions validées (session brainstorming)

- **Structure** : passage d'un écran unique scrollable à un `PageView` de **3 pages** avec indicateur de progression (dots).
- **Position mascotte** (validée via maquettes comparatives) : centrée horizontalement, dans le tiers supérieur-milieu de l'écran, jamais collée au bord haut (padding généreux avant), taille contenue (~35% de la hauteur d'écran sur P1, plus petite sur P2/P3 où il y a du contenu additionnel). Pattern aligné sur les standards observés (Duolingo, Headspace, Revolut, Airbnb) : illustration centrée = point focal en lecture F/Z, jamais un élément latéral.
- **Poses mascotte par page** : utilise les presets `DonyMascotteType` déjà existants dans le design system, pas de nouvel asset. P1 = `bienvenue`, P2 = `securise` (ou `joyeux`), P3 = `confiant`.
- **Contenu P2 (avantages)** : option "groupé" retenue — les 3 avantages (Vérifié/Tracé/Garanti) restent visibles ensemble sur une seule page, pas de sous-carrousel un-par-un (qui aurait ajouté un indicateur imbriqué et allongé le flow au-delà de 3 pages).
- **P3 (confiance + CTA)** : pas de statistiques chiffrées inventées (nb utilisateurs, note store) — l'app est jeune, un chiffre non vérifiable nuirait à la confiance plutôt que la renforcer. Message rassurant textuel + mascotte `confiant` à la place.

## Pages

### Page 1 — Accroche
- Bouton "Passer" en haut à droite (visible P1/P2, masqué P3).
- Mascotte `DonyMascotteAnimated(type: bienvenue)`, centrée, padding top ~12-14% avant, taille ~35% hauteur écran.
- Titre "Envoyez un colis **chez vous**, autrement." (accent Caveat sur "chez vous", inchangé du design actuel — `tt.displayLarge` + `DonyTypography.caveat`).
- Sous-titre "Voyageurs vérifiés. Suivi en temps réel. Et le sourire de votre famille à l'arrivée." (`tt.bodyLarge`, `cs.onSurfaceVariant`).
- `DonyStepIndicator` (page 1/3).
- CTA "Suivant".

### Page 2 — Avantages
- Bouton "Passer" en haut à droite.
- Mascotte `DonyMascotteAnimated(type: securise)`, plus petite que P1 (proportion réduite pour laisser la place aux 3 cartes).
- Titre court (ex. "Pourquoi voyager en confiance ?").
- 3 cartes avantages réutilisant le pattern `_FeatureCard` actuel (icône `DonyIcon` dans conteneur `cs.primaryContainer`, `DonyShadow.xs`, `DonyRadius.card`) — contenu inchangé (Vérifié / Tracé / Garanti), toutes visibles sans scroll additionnel dans la page.
- `DonyStepIndicator` (page 2/3).
- CTA "Suivant".

### Page 3 — Confiance + CTA
- Pas de bouton "Passer" (redondant, le CTA est déjà l'action finale).
- Mascotte `DonyMascotteAnimated(type: confiant)`.
- Titre/message rassurant sans chiffre inventé.
- `DonyStepIndicator` (page 3/3).
- CTA "Commencer".
- Footer CGU / politique de confidentialité (inchangé, texte + liens actuels).

## Navigation

- Swipe horizontal autorisé dans les deux sens entre les 3 pages (`PageView` standard, pas de `NeverScrollableScrollPhysics`).
- "Passer" (P1/P2) navigue directement vers la même destination que le CTA "Commencer" actuel (route post-onboarding inchangée — à vérifier dans le code existant du bouton `Commencer` et réutiliser telle quelle).
- CTA de chaque page (`Suivant`/`Suivant`/`Commencer`) avance d'une page via `PageController.nextPage`, dernière page déclenche l'action actuelle du bouton "Commencer".

## Composants réutilisés (design system)

- `DonyMascotteAnimated` (presets existants, pas de nouvel asset).
- `DonyStepIndicator` (dots de progression, déjà dans `lib/core/design/widgets/dony_step_indicator.dart`).
- `_FeatureCard` existant (ou promotion vers un widget partagé si le refactor s'y prête — à trancher en phase implémentation, YAGNI : ne pas sur-abstraire si utilisé seulement ici).
- `DonyButton`, `DonyLayout.constrained`, tokens `DonySpacing`/`DonyRadius`/`DonyShadow`, `tt.displayLarge`/`tt.bodyLarge`, `DonyTypography.caveat`.
- `DonyPageScaffold` à évaluer comme wrapper standard (actuellement l'écran fait son `Scaffold`/`SafeArea` à la main) — à confirmer en phase plan si le composant convient sans régression.

## Hors scope

- Pas de contenu marketing chiffré (statistiques, notes) tant qu'aucune donnée réelle n'est fournie.
- Pas de refonte du contenu des 3 avantages eux-mêmes (Vérifié/Tracé/Garanti) — seulement leur mise en scène.
- Pas de changement de la route post-onboarding ni de la logique d'auth qui suit.

## Tests

- Adapter `test/features/auth/presentation/screens/onboarding_screen_test.dart` : vérifier les 3 pages, le swipe, le comportement "Passer", l'indicateur de page, et que chaque CTA avance/termine correctement.
- Couverture ≥ 90% conformément à la politique de test du projet (CLAUDE.md).
