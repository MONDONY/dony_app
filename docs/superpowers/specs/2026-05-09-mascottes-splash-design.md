# Mascottes + splash natif — Design dony app

**Date :** 2026-05-09
**Status :** Spec — en attente review utilisateur
**Spec 3/3** d'un chantier design system : dark mode → glassmorphism → **mascottes**
**Indépendant des specs 1 et 2** — peut être implémenté avant ou après

---

## Contexte

L'application dispose d'un dossier `assets/mascottes/` contenant **12 illustrations JPG** de la mascotte officielle dony, mais :
- Le dossier n'est **pas déclaré** dans `pubspec.yaml` (sous le bloc `flutter.assets`) — actuellement seul `assets/logos/` l'est. Les mascottes sont donc **invisibles à l'application** dans son état actuel.
- Aucun écran ne les utilise.
- Le splash natif (configuré via `flutter_native_splash`) affiche `assets/logos/splash_colis.png` au démarrage de l'app, avant Flutter — l'utilisateur veut que ce soit la mascotte qui salue à la place.

L'utilisateur veut intégrer la mascotte de manière **systématique** dans le DS et sur quelques écrans-clés.

Décisions cadrées :
- Créer `DonyMascotte` (widget + enum) dans le DS — centralise les chemins, évite `'assets/mascottes/salue.jpg'` éparpillé
- Étendre `DonyEmptyState` avec un paramètre mascotte (override l'icône actuelle)
- Mascotte sur l'onboarding (mono-page → une seule mascotte)
- Mascotte sur l'écran de succès de scan/livraison (dialog dans `qr_scanner_screen.dart`)
- Splash natif : remplacer `splash_colis.png` par `salue.jpg` (le `SplashScreen` Flutter, qui n'affiche que le `DonyLogo` texte, **n'est pas modifié**)

---

## Inventaire des mascottes disponibles

| Fichier | Sémantique | Usage suggéré |
|---|---|---|
| `salue.jpg` | Saluer / bienvenue | **Splash natif**, onboarding |
| `tenant_colis.jpg` | Tenant un colis (rôle expéditeur) | Premier scan, tutoriel envoi |
| `colis_livre.jpg` | Colis livré (succès final) | **Dialog scan = step final "delivered"** |
| `pouce_leve.jpg` | Pouce levé (validation intermédiaire) | **Dialog scan = step intermédiaire** |
| `dans_avion.jpg` | Dans un avion | Étape "embarqué" du tracking |
| `sur_avion.jpg` | Sur un avion | Étape "vol" du tracking |
| `a_moto.jpg` | À moto (livraison locale) | Étape "remise destinataire" |
| `a_voiture.jpg` | En voiture | Étape "transit terrestre" |
| `courir.jpg` | Mascotte qui court | États "loading" longs (en option) |
| `no_data.jpg` | État vide | **DonyEmptyState type=empty** |
| `perdu.jpg` | État perdu / erreur | **DonyEmptyState type=error** |

> **Note :** le fichier `Suppression du fond d'une image.png` présent dans le dossier semble être un working file (nom français + .png unique parmi les .jpg). Il sera **exclu** de l'enum et ne sera pas embarqué.
>
> **Note 2 :** le fichier réel s'appelle `pouce_levé.jpg` avec accent. Pour éviter les soucis de path et d'encoding sur certaines plateformes, on **renomme** à `pouce_leve.jpg` (sans accent) avant de déclarer l'asset. Action incluse dans le plan d'exécution.

---

## Objectifs

1. Déclarer `assets/mascottes/` dans `pubspec.yaml`
2. Renommer `pouce_levé.jpg` → `pouce_leve.jpg` (élimine l'accent du path)
3. Créer `DonyMascotte` widget + enum `DonyMascotteType` dans `lib/core/design/widgets/`
4. Étendre `DonyEmptyState` avec un paramètre `DonyMascotteType? mascotte` (override l'icône)
5. Intégrer la mascotte sur l'onboarding (au-dessus du `DonyLogo`)
6. Intégrer la mascotte sur le dialog de succès de scan (`qr_scanner_screen.dart#_showSuccessDialog`)
7. Remplacer `splash_colis.png` par `salue.jpg` dans la config `flutter_native_splash` du `pubspec.yaml`, régénérer le splash natif
8. Documentation : mention dans `CLAUDE.md` du DS, exemples d'usage

## Hors scope

- Dark mode (spec 1) / Glassmorphism (spec 2)
- Animation Lottie / illustrations animées des mascottes (les jpg statiques suffisent)
- Mascotte dans tous les autres `DonyEmptyState` du codebase (les 6 usages identifiés bénéficient automatiquement quand l'appelant ajoute le paramètre `mascotte:` — pas de migration forcée)
- Mascotte dans le `SplashScreen` Flutter (l'utilisateur a explicitement choisi "splash natif uniquement")
- Mascotte dynamique selon l'étape du tracking (utilisations potentielles `dans_avion`, `a_moto`, etc.) — c'est une feature à part qui sortirait du scope DS
- Conversion des JPG en WebP/AVIF pour la taille (les JPG sont OK pour le MVP)

---

## Architecture

### 1. Renommage et déclaration des assets

#### `assets/mascottes/pouce_levé.jpg` → `assets/mascottes/pouce_leve.jpg`

Renommage filesystem effectué dans le plan d'exécution. L'accent dans un path peut poser des problèmes :
- Sur Android : encodage variable selon le filesystem
- Dans les tests Dart : nécessite des chaînes Unicode dans les paths
- Source d'erreurs `Unable to load asset`

#### `pubspec.yaml` (modifié)

Section `flutter.assets` étendue :

```yaml
flutter:
  uses-material-design: true
  assets:
    - assets/logos/
    - assets/logos/2.0x/
    - assets/logos/3.0x/
    - assets/mascottes/        # NEW
```

Le fichier `Suppression du fond d'une image.png` n'est pas listé individuellement, mais il sera **embarqué malgré tout** car le déclareur de répertoire prend tout le contenu. Action à prendre : **supprimer ce fichier** du dossier (working file inutilisé), pour ne pas alourdir l'APK.

### 2. `DonyMascotte` — `lib/core/design/widgets/dony_mascotte.dart` (nouveau)

```dart
import 'package:dony/core/design/tokens/spacing_tokens.dart';
import 'package:flutter/material.dart';

/// Mascotte officielle dony.
///
/// Centralise les chemins d'assets — préfère [DonyMascotte] à
/// `Image.asset('assets/mascottes/...')` pour garantir cohérence et typage.
///
/// Exemple :
/// ```dart
/// DonyMascotte(
///   type: DonyMascotteType.salue,
///   size: DonyMascotteSize.lg,
/// )
/// ```
enum DonyMascotteType {
  salue,
  tenantColis,
  colisLivre,
  pouceLeve,
  dansAvion,
  surAvion,
  aMoto,
  aVoiture,
  courir,
  noData,
  perdu;

  String get assetPath => switch (this) {
        salue        => 'assets/mascottes/salue.jpg',
        tenantColis  => 'assets/mascottes/tenant_colis.jpg',
        colisLivre   => 'assets/mascottes/colis_livre.jpg',
        pouceLeve    => 'assets/mascottes/pouce_leve.jpg',
        dansAvion    => 'assets/mascottes/dans_avion.jpg',
        surAvion     => 'assets/mascottes/sur_avion.jpg',
        aMoto        => 'assets/mascottes/a_moto.jpg',
        aVoiture     => 'assets/mascottes/a_voiture.jpg',
        courir       => 'assets/mascottes/courir.jpg',
        noData       => 'assets/mascottes/no_data.jpg',
        perdu        => 'assets/mascottes/perdu.jpg',
      };

  /// Description sémantique pour [Semantics] — accessibilité.
  String get semanticLabel => switch (this) {
        salue        => 'Mascotte qui salue',
        tenantColis  => 'Mascotte tenant un colis',
        colisLivre   => 'Colis livré',
        pouceLeve    => 'Pouce levé',
        dansAvion    => 'Mascotte dans un avion',
        surAvion     => 'Mascotte sur un avion',
        aMoto        => 'Mascotte à moto',
        aVoiture     => 'Mascotte en voiture',
        courir       => 'Mascotte qui court',
        noData       => 'Aucun élément',
        perdu        => 'Quelque chose s\'est perdu',
      };
}

/// Tailles standardisées pour la mascotte.
enum DonyMascotteSize {
  sm(64),
  md(96),
  lg(160),
  xl(240);

  const DonyMascotteSize(this.dimension);
  final double dimension;
}

class DonyMascotte extends StatelessWidget {
  const DonyMascotte({
    super.key,
    required this.type,
    this.size = DonyMascotteSize.md,
    this.customDimension,
    this.fit = BoxFit.contain,
    this.borderRadius,
  });

  final DonyMascotteType type;
  final DonyMascotteSize size;
  /// Override de la taille standard. Prend le pas sur [size] si non null.
  final double? customDimension;
  final BoxFit fit;
  /// Si non null, applique un ClipRRect avec ce rayon (utile pour cacher le fond JPG).
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final dim = customDimension ?? size.dimension;

    final image = Image.asset(
      type.assetPath,
      width: dim,
      height: dim,
      fit: fit,
      semanticLabel: type.semanticLabel,
    );

    final wrapped = borderRadius != null
        ? ClipRRect(borderRadius: borderRadius!, child: image)
        : image;

    return Semantics(
      image: true,
      label: type.semanticLabel,
      child: wrapped,
    );
  }
}
```

**Points clés :**
- Les chemins sont centralisés dans l'enum — un seul endroit à modifier si on renomme
- `semanticLabel` pour l'accessibilité (lecteur d'écran)
- `customDimension` permet override sans casser l'API standardisée
- `borderRadius` optionnel — utile car les JPG ont un fond non transparent ; appliquer un radius arrondit les coins

### 3. Extension de `DonyEmptyState` — `lib/core/design/widgets/dony_empty_state.dart` (modifié)

Ajout d'un paramètre optionnel `mascotte: DonyMascotteType?`. Logique :

- Si `mascotte != null` : affiche `DonyMascotte` au lieu de `DonyIconContainer`, en taille `DonyMascotteSize.lg`
- Sinon, comportement actuel inchangé (icône)

Snippet du nouveau build (extrait pertinent) :

```dart
class DonyEmptyState extends StatelessWidget {
  const DonyEmptyState({
    super.key,
    required this.title,
    this.description,
    this.icon,
    this.mascotte,                          // NEW
    this.type = DonyEmptyStateType.empty,
    this.actionLabel,
    this.onAction,
    this.padding,
  });

  final DonyMascotteType? mascotte;          // NEW
  // ... autres champs

  @override
  Widget build(BuildContext context) {
    // ... loading branch inchangée

    final illustration = mascotte != null
        ? DonyMascotte(type: mascotte!, size: DonyMascotteSize.lg)
              .animate()
              .fadeIn(duration: 400.ms, curve: Curves.easeOutCubic)
              .scaleXY(begin: 0.82, duration: 400.ms, curve: Curves.easeOutBack)
        : DonyIconContainer(icon: icon ?? defaultIcon, /* ... */)
              .animate() /* ... */;

    return Center(
      child: Padding(
        padding: padding ?? const EdgeInsets.all(DonySpacing.huge),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            illustration,
            const SizedBox(height: DonySpacing.xl),
            // ... title + description + action inchangés
          ],
        ),
      ),
    );
  }
}
```

**API rétrocompatible :** les 6 usages existants (`bid_list_screen`, `traveler_profile_screen`, etc.) continuent de fonctionner sans modification. Ils peuvent **opt-in** au paramètre mascotte progressivement.

### 4. Intégration onboarding — `lib/features/auth/presentation/screens/onboarding_screen.dart` (modifié)

L'écran d'onboarding actuel est **mono-page** (pas de `PageView`). Structure :
- `DonyLogo(fontSize: 48)` (ligne 46)
- Headline "Envoyez un colis"
- Tagline "chez vous, autrement."
- Sous-titre paragraphe
- 3 `_FeatureCard` (Vérifié / Tracé / Garanti)
- Footer avec CTA

Modification : insérer une `DonyMascotte(salue, size: lg)` **au-dessus** du `DonyLogo`, avec une animation d'entrée :

```dart
DonyMascotte(
  type: DonyMascotteType.salue,
  size: DonyMascotteSize.lg,
  borderRadius: BorderRadius.circular(DonyRadius.card.toDouble()),
)
    .animate()
    .fadeIn(duration: 400.ms)
    .scaleXY(begin: 0.85, duration: 500.ms, curve: Curves.easeOutBack),
const SizedBox(height: DonySpacing.lg),
const DonyLogo(fontSize: 48),
// ... reste inchangé
```

Le `borderRadius` est appliqué pour adoucir le fond JPG sur le fond `DonyColors.bgApp` (clair). Sans ça, on verrait un rectangle dur.

### 5. Intégration succès scan — `lib/features/tracking/presentation/screens/qr_scanner_screen.dart` (modifié)

Le `_showSuccessDialog` (lignes 439-488) actuel affiche `Icons.check_circle_rounded` dans un `Container` rond avec fond `DonyColors.successLight`. On le remplace par une mascotte :

- Mascotte choisie selon le label de l'étape :
  - Si le `stepLabel` correspond à l'étape finale (livraison terminée — à matcher sur la chaîne par ex. contient "livr" ou un enum si dispo) : `DonyMascotteType.colisLivre`
  - Sinon (étape intermédiaire) : `DonyMascotteType.pouceLeve`

> **Note d'implémentation :** le `stepLabel` est une chaîne libre serveur. Si possible, on doit **lire l'enum d'événement** (`TrackingEventType` ou similaire dans `tracking_event_model.dart`) plutôt que parser la string. À vérifier au moment de l'implémentation. Si l'enum n'est pas exposé au scanner, fallback sur du matching de chaîne avec une fonction privée `_isFinalDeliveryStep(String label)`.

Snippet de la modification :

```dart
void _showSuccessDialog(String label) {
  final tt = Theme.of(context).textTheme;
  final isFinal = _isFinalDeliveryStep(label);
  final mascotteType = isFinal
      ? DonyMascotteType.colisLivre
      : DonyMascotteType.pouceLeve;

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DonyRadius.sheet)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DonyMascotte(
            type: mascotteType,
            size: DonyMascotteSize.lg,
            borderRadius: BorderRadius.circular(DonyRadius.card.toDouble()),
          ),
          const SizedBox(height: DonySpacing.base),
          Text(
            isFinal ? 'Colis livré !' : 'Scan enregistré !',
            style: tt.headlineMedium?.copyWith(color: DonyColors.ink900),
          ),
          // ... description + CTA inchangés
        ],
      ),
      // ...
    ),
  );
}

bool _isFinalDeliveryStep(String label) {
  final l = label.toLowerCase();
  return l.contains('livr') || l.contains('remis') || l.contains('deliver');
}
```

### 6. Splash natif — `pubspec.yaml` (modifié)

Section `flutter_native_splash` :

```yaml
flutter_native_splash:
  color: "#FFFFFF"
  color_dark: "#FFFFFF"
  image: assets/mascottes/salue.jpg     # CHANGED (était assets/logos/splash_colis.png)
  android_12:
    color: "#FFFFFF"
    icon_background_color: "#FFFFFF"
    image: assets/mascottes/salue.jpg   # CHANGED
  ios: true
  android: true
```

**Action après modification :** régénération obligatoire :

```bash
flutter pub get
flutter pub run flutter_native_splash:create
```

Cette commande régénère :
- `android/app/src/main/res/drawable*/launch_background.xml` + assets PNG
- `ios/Runner/Assets.xcassets/LaunchImage.imageset/...`
- `ios/Runner/Base.lproj/LaunchScreen.storyboard`

> **Considération JPG vs PNG transparent :** `flutter_native_splash` accepte les JPG, mais le rendu produit un rectangle plein (JPG = pas de transparence). Le fond blanc `#FFFFFF` est conservé autour ; visuellement OK si la mascotte a un fond blanc d'origine, sinon un liseré sera visible. Vérification visuelle requise après génération. Si le rendu est moche, conversion préalable de `salue.jpg` en PNG transparent (action incluse en option dans le plan d'exécution).

> **Le fichier `splash_colis.png` reste dans `assets/logos/`** mais n'est plus référencé. Action : **supprimer** le fichier après confirmation visuelle du nouveau splash, pour ne pas alourdir l'APK.

### 7. Documentation

#### `lib/core/design/CLAUDE.md` (modifié)

Nouvelle section **Mascotte** :
- Rappel : `DonyMascotte` centralisé, ne pas faire `Image.asset('assets/mascottes/...')` directement
- Tableau des types et leurs usages recommandés
- Snippet : intégration dans `DonyEmptyState`
- Snippet : intégration standalone

### 8. Tests

Cible **≥ 90 %** sur les fichiers touchés.

#### 8.1 Widget tests `DonyMascotte`

```dart
group('DonyMascotte', () {
  testWidgets('rend l\'image au bon path selon le type', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: DonyMascotte(type: DonyMascotteType.salue),
    ));
    final imageWidget = tester.widget<Image>(find.byType(Image));
    final assetImage = imageWidget.image as AssetImage;
    expect(assetImage.assetName, 'assets/mascottes/salue.jpg');
  });

  testWidgets('utilise size.dimension par défaut', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: DonyMascotte(type: DonyMascotteType.salue, size: DonyMascotteSize.lg),
    ));
    final imageWidget = tester.widget<Image>(find.byType(Image));
    expect(imageWidget.width, 160);
    expect(imageWidget.height, 160);
  });

  testWidgets('customDimension override size', (tester) async { /* ... */ });

  testWidgets('applique borderRadius si fourni', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: DonyMascotte(
        type: DonyMascotteType.salue,
        borderRadius: BorderRadius.circular(20),
      ),
    ));
    expect(find.byType(ClipRRect), findsOneWidget);
  });

  testWidgets('Semantics expose le label', (tester) async { /* ... */ });

  test('chaque DonyMascotteType a un assetPath unique et non vide', () {
    final paths = DonyMascotteType.values.map((t) => t.assetPath).toSet();
    expect(paths.length, DonyMascotteType.values.length);
    for (final p in paths) {
      expect(p, isNotEmpty);
      expect(p, startsWith('assets/mascottes/'));
    }
  });
});
```

#### 8.2 Widget tests `DonyEmptyState` étendu

```dart
testWidgets('affiche DonyMascotte si mascotte fourni', (tester) async {
  await tester.pumpWidget(MaterialApp(
    home: const Scaffold(
      body: DonyEmptyState(
        title: 'Vide',
        mascotte: DonyMascotteType.noData,
      ),
    ),
  ));
  expect(find.byType(DonyMascotte), findsOneWidget);
  expect(find.byType(DonyIconContainer), findsNothing);
});

testWidgets('fallback icon si mascotte null (rétrocompat)', (tester) async {
  // L'API existante doit continuer à fonctionner
});
```

#### 8.3 Widget tests intégrations

- Onboarding : présence de `DonyMascotte(salue)` au-dessus du `DonyLogo`
- Scanner success : tap sur scan simulé → dialog contient `DonyMascotte` (selon stepLabel)

#### 8.4 Tests d'unité `_isFinalDeliveryStep`

Couvre les variantes : "Colis livré", "Remis au destinataire", "Package delivered" → true. "Embarqué", "En vol" → false.

#### 8.5 Vérification que les assets sont déclarés

Petit test post-build qui vérifie que `rootBundle.load('assets/mascottes/salue.jpg')` ne lève pas. Sécurité contre l'oubli de la déclaration `pubspec.yaml`.

---

## Données / état

Aucun. Pas de stockage, pas de bloc, pas de réseau.

---

## Risques

| Risque | Mitigation |
|---|---|
| Le splash natif rend mal car les JPG n'ont pas de transparence | Vérification visuelle après `flutter pub run flutter_native_splash:create`. Si nécessaire, conversion préalable `salue.jpg` → `salue.png` (avec fond transparent ou fond blanc explicite). |
| Les paths d'assets cassent à cause de l'accent dans `pouce_levé.jpg` | Renommage filesystem inclus dans le plan |
| L'APK gagne ~12 × 50-200 KB = 1-2 MB en taille | Acceptable pour le MVP. Optimisation WebP/AVIF possible plus tard hors scope. |
| Le `Suppression du fond d'une image.png` est embarqué inutilement | Suppression du fichier inclus dans le plan |
| `_isFinalDeliveryStep` matching de chaîne est fragile (i18n future, label serveur peut changer) | Documenté comme fallback ; vérifier si un enum d'événement existe pour faire un match propre. À durcir dès qu'un changement i18n est planifié. |
| Régression `OnboardingScreen` après ajout mascotte | Test widget vérifiant la présence + l'ordre des éléments |
| `flutter_native_splash:create` échoue (permissions, format JPG) | Logguer la sortie de la commande, fallback PNG si nécessaire |

---

## Plan d'exécution (à découper par writing-plans)

1. **Cleanup assets** :
   - Supprimer `assets/mascottes/Suppression du fond d'une image.png`
   - Renommer `assets/mascottes/pouce_levé.jpg` → `assets/mascottes/pouce_leve.jpg`
2. **`pubspec.yaml`** :
   - Ajouter `assets/mascottes/` dans `flutter.assets`
   - Modifier `flutter_native_splash.image` (et `android_12.image`) pour pointer sur `assets/mascottes/salue.jpg`
   - `flutter pub get`
3. **Créer `DonyMascotte`** : widget + enum + tests unitaires
4. **Étendre `DonyEmptyState`** avec param `mascotte` + tests
5. **Intégration onboarding** : ajouter `DonyMascotte(salue)` au-dessus du `DonyLogo` + animations + test widget
6. **Intégration scanner success** : modifier `_showSuccessDialog` + helper `_isFinalDeliveryStep` + tests unit + test widget
7. **Régénération splash natif** : `flutter pub run flutter_native_splash:create` + vérification visuelle (Android emulator + iOS simulator si possible)
8. **Suppression `splash_colis.png`** après vérif visuelle OK (fichier inutilisé)
9. **Documentation** : mise à jour `lib/core/design/CLAUDE.md` avec section Mascotte
10. **Vérification finale** : `flutter analyze`, `flutter test --coverage`, vérification couverture ≥ 90 %, test manuel des 3 écrans (splash, onboarding, dialog scan succès)

---

## Critères d'acceptation

- [ ] `assets/mascottes/` est déclaré dans `pubspec.yaml`
- [ ] Le fichier `Suppression du fond d'une image.png` est supprimé
- [ ] `pouce_levé.jpg` est renommé en `pouce_leve.jpg`
- [ ] `DonyMascotte` widget existe avec enum `DonyMascotteType` couvrant les 11 mascottes utilisées
- [ ] `DonyEmptyState` accepte le param `mascotte` ; le rétrocompat est préservé (les 6 usages existants compilent et rendent comme avant sans changement)
- [ ] L'écran d'onboarding affiche la mascotte `salue` au-dessus du logo
- [ ] Le dialog de succès scan affiche `colisLivre` ou `pouceLeve` selon l'étape
- [ ] Le splash natif affiche `salue.jpg` au lieu de `splash_colis.png` (vérifié visuellement)
- [ ] `flutter pub run flutter_native_splash:create` exécuté et fichiers générés commités
- [ ] `splash_colis.png` est supprimé du dossier `assets/logos/`
- [ ] `lib/core/design/CLAUDE.md` contient une section Mascotte
- [ ] `flutter test --coverage` passe à 0 rouge avec couverture ≥ 90 % sur les fichiers touchés
- [ ] `flutter analyze` ne signale aucune nouvelle warning
- [ ] Vérification manuelle : ouvrir l'app → splash mascotte → onboarding mascotte ; effectuer un scan QR → dialog mascotte

---

## Décisions techniques notables

- **Enum strict pour les mascottes** — pas de fonction `Image.asset(...)` libre. Discipline pour ne pas introduire de path strings qui dérivent.
- **`DonyMascotte` ne dépend pas de `Theme.brightness`** — les illustrations JPG sont les mêmes en light et dark. Si plus tard on veut des variantes sombres, on changera l'enum ou on ajoutera un paramètre.
- **`borderRadius` optionnel** — les JPG ont un fond non transparent. Le `borderRadius` permet d'arrondir les coins pour s'intégrer harmonieusement aux surfaces du DS.
- **`semanticLabel` obligatoire dans l'enum** — accessibilité. L'utilisateur de lecteur d'écran doit comprendre l'illustration.
- **API `mascotte` dans `DonyEmptyState`, pas via le `type`** — séparer la mascotte (illustration) du type sémantique (empty / error / loading) permet de combiner librement (ex: type empty avec mascotte `noData` ou `salue` selon le contexte).
- **Splash natif uniquement, pas le `SplashScreen` Flutter** — choix utilisateur explicite. Documenté dans la spec pour mémoire.
- **Fallback string-matching pour `_isFinalDeliveryStep`** — pragmatique pour le MVP. Si l'enum d'événement est exposé proprement, on bascule sur un match d'enum plus tard.
- **Régénération splash via `flutter_native_splash:create`** — c'est l'outil officiel, on l'utilise. Pas de bidouillage manuel des XML Android.
- **Pas de conversion WebP/AVIF** — gain marginal (1-2 MB) pour effort non négligeable, hors scope MVP.
