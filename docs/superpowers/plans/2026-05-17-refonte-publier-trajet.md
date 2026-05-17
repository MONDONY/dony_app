# Refonte « Publier un trajet » — Plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Corriger les 15 problèmes UX du bottom sheet « Publier un trajet » (3 bloquants, 5 majeurs, 7 polish) + le bug de débordement de l'écran payout Stripe, en respectant les maquettes `maquettes/v6/`.

**Architecture:** Découpage « au fur et à mesure » du fichier `create_announcement_bottom_sheet.dart` (2865 lignes) : extraction des 3 corps d'étape dans `create_announcement/`, le fichier d'origine ne garde que la coquille. Nouveau contrôle de capacité à 4 chips. Icônes Phosphor via un mapping sémantique. State BLoC uniquement.

**Tech Stack:** Flutter · flutter_bloc · phosphor_flutter (nouveau) · flutter_animate · bloc_test.

**Spec source :** `docs/superpowers/specs/2026-05-17-refonte-publier-trajet-design.md`

> **Note aux implémenteurs :** ce plan refactore un fichier legacy de 2865 lignes.
> Pour chaque tâche qui modifie `create_announcement_bottom_sheet.dart`, **lire
> d'abord la zone concernée** (les numéros de ligne indiqués datent du 2026-05-17,
> commit `0d2d292`, et peuvent dériver). Les classes privées repères : `_buildForm`
> (~1771), `_buildKgFreeDisplay` (~1140), `_FieldCard`/`_FieldIcon`/`_SectionCard`/
> `_SectionLabel`/`_TimeRow`/`_DateRow`/`_StepperHeader`/`_StepNode` (~2454-2865).

---

## Structure des fichiers

**Créés :**
- `lib/core/design/dony_icons.dart` — mapping sémantique Phosphor
- `lib/features/matching/presentation/widgets/create_announcement/trajet_step.dart`
- `lib/features/matching/presentation/widgets/create_announcement/lieux_capacite_step.dart`
- `lib/features/matching/presentation/widgets/create_announcement/prix_conditions_step.dart`
- `lib/features/matching/presentation/widgets/create_announcement/capacity_control.dart`
- Tests miroirs sous `test/`

**Modifiés :**
- `pubspec.yaml` — dépendance `phosphor_flutter`
- `lib/features/matching/bloc/announcement_form_state.dart` — `CapacityUnit.custom`
- `lib/features/matching/bloc/announcement_form_bloc.dart` — logique capacité
- `lib/core/design/widgets/dony_text_field.dart` — variante tappable
- `lib/features/matching/presentation/widgets/create_announcement_bottom_sheet.dart` — allégé
- `lib/features/payments/presentation/screens/payout_onboarding_screen.dart` — fix B3

**Supprimé :** `lib/features/matching/presentation/widgets/capacity_selector.dart`

---

## PHASE 0 — Setup

### Task 0: Ajouter Phosphor et le mapping d'icônes

**Files:**
- Modify: `pubspec.yaml`
- Create: `lib/core/design/dony_icons.dart`

- [ ] **Step 1: Ajouter la dépendance**

Dans `pubspec.yaml`, sous `dependencies:`, à côté de `flutter_svg`, ajouter :

```yaml
  phosphor_flutter: ^2.1.0
```

- [ ] **Step 2: Installer**

Run: `flutter pub get`
Expected: `Got dependencies!` sans erreur de résolution.

- [ ] **Step 3: Créer le mapping sémantique**

Create `lib/core/design/dony_icons.dart` :

```dart
import 'package:flutter/widgets.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Mapping sémantique des icônes dony → Phosphor.
/// L'app ne référence jamais Phosphor directement : toujours via DonyIcons.
class DonyIcons {
  DonyIcons._();

  // Trajet
  static const IconData departureCity = PhosphorIconsRegular.airplaneTakeoff;
  static const IconData arrivalCity = PhosphorIconsRegular.airplaneLanding;
  static const IconData time = PhosphorIconsRegular.clock;
  static const IconData date = PhosphorIconsRegular.calendarBlank;

  // Lieux
  static const IconData mapPin = PhosphorIconsRegular.mapPin;
  static const IconData locate = PhosphorIconsRegular.crosshair;

  // Capacité
  static const IconData suitcase = PhosphorIconsRegular.suitcaseRolling;
  static const IconData infinity = PhosphorIconsRegular.infinity;

  // Prix & paiement
  static const IconData editPrice = PhosphorIconsRegular.pencilSimple;
  static const IconData card = PhosphorIconsRegular.creditCard;
  static const IconData cash = PhosphorIconsRegular.money;
  static const IconData escrow = PhosphorIconsRegular.lockKey;
  static const IconData transfer = PhosphorIconsRegular.lightning;
  static const IconData bank = PhosphorIconsRegular.bank;
  static const IconData tip = PhosphorIconsRegular.lightbulb;

  // Navigation & actions
  static const IconData close = PhosphorIconsRegular.x;
  static const IconData back = PhosphorIconsRegular.caretLeft;
  static const IconData chevron = PhosphorIconsRegular.caretRight;
  static const IconData arrowRight = PhosphorIconsRegular.arrowRight;
  static const IconData check = PhosphorIconsRegular.check;
  static const IconData add = PhosphorIconsRegular.plus;
  static const IconData publish = PhosphorIconsRegular.rocketLaunch;
  static const IconData confirmed = PhosphorIconsFill.sealCheck;

  // Modes de transport
  static const IconData transportPlane = PhosphorIconsRegular.airplaneTilt;
  static const IconData transportCar = PhosphorIconsRegular.car;
  static const IconData transportTrain = PhosphorIconsRegular.train;
  static const IconData transportBus = PhosphorIconsRegular.bus;
  static const IconData transportBoat = PhosphorIconsRegular.boat;
  static const IconData transportOther = PhosphorIconsRegular.dotsThreeOutline;
}
```

- [ ] **Step 4: Vérifier la compilation**

Run: `flutter analyze lib/core/design/dony_icons.dart`
Expected: `No issues found!` (si un nom Phosphor n'existe pas, l'analyzer le signale — corriger avec le nom exact du package).

- [ ] **Step 5: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/core/design/dony_icons.dart
git commit -m "feat(design): ajouter phosphor_flutter et le mapping DonyIcons"
```

---

## PHASE 1 — Bloquants

### Task 1: Extraire `trajet_step.dart` (refactor pur)

But : sortir le corps de l'étape 1 du fichier monstre **sans changer le comportement**, pour pouvoir y travailler ensuite.

**Files:**
- Read first: `create_announcement_bottom_sheet.dart` (zone `_buildForm`, partie étape 1)
- Create: `create_announcement/trajet_step.dart`
- Modify: `create_announcement_bottom_sheet.dart`

- [ ] **Step 1: Lire la zone étape 1**

Lire `create_announcement_bottom_sheet.dart` autour de `_buildForm` (~1771) et identifier le bloc de widgets de l'étape 1 (champs ville/heure/date + mode de transport).

- [ ] **Step 2: Créer le widget extrait**

Create `create_announcement/trajet_step.dart` : un `StatelessWidget` (ou `StatefulWidget` si la zone gère des `TextEditingController`/`FocusNode` — dans ce cas déplacer aussi ces contrôleurs) nommé `TrajetStep`, recevant en paramètres les callbacks/contrôleurs dont la zone a besoin. Coller le contenu de l'étape 1 à l'identique.

- [ ] **Step 3: Brancher dans la coquille**

Dans `create_announcement_bottom_sheet.dart`, remplacer le bloc étape 1 de `_buildForm` par `TrajetStep(...)` avec les mêmes dépendances. Ajouter l'import.

- [ ] **Step 4: Vérifier zéro régression**

Run: `flutter analyze`
Expected: `No issues found!`
Run: `flutter test test/features/matching/`
Expected: les tests existants passent toujours (comportement inchangé).

- [ ] **Step 5: Commit**

```bash
git add lib/features/matching/presentation/widgets/
git commit -m "refactor(matching): extraire TrajetStep du bottom sheet"
```

---

### Task 2: B1 — Autocomplétion ville en liste inline

**Files:**
- Modify: `create_announcement/trajet_step.dart`
- Test: `test/features/matching/presentation/widgets/create_announcement/trajet_step_test.dart`

- [ ] **Step 1: Écrire le widget test (échec attendu)**

Create le fichier de test :

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// importer TrajetStep et les dépendances BLoC nécessaires

void main() {
  testWidgets('les suggestions de ville s\'affichent sous le champ', (tester) async {
    await tester.pumpWidget(/* MaterialApp + BlocProvider + TrajetStep */);
    await tester.enterText(find.byKey(const Key('arrivalCityField')), 'Abidja');
    await tester.pump(const Duration(milliseconds: 400)); // debounce
    expect(find.text('Abidjan, Côte d\'Ivoire'), findsOneWidget);
  });

  testWidgets('toucher une suggestion remplit le champ et ferme la liste',
      (tester) async {
    await tester.pumpWidget(/* ... */);
    await tester.enterText(find.byKey(const Key('arrivalCityField')), 'Abidja');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Abidjan, Côte d\'Ivoire'));
    await tester.pump();
    expect(find.text('Abidjan, Côte d\'Ivoire'), findsNothing); // liste fermée
  });
}
```

- [ ] **Step 2: Lancer le test (échec attendu)**

Run: `flutter test test/features/matching/presentation/widgets/create_announcement/trajet_step_test.dart`
Expected: FAIL (clés/suggestions absentes).

- [ ] **Step 3: Implémenter la liste inline**

Dans `trajet_step.dart` : sous chaque champ ville, rendre les suggestions comme un `Column` (ou `ListView` borné) **dans le flux scrollable** — jamais en `Overlay`/`OverlayEntry` flottant. Donner les `Key('departureCityField')` / `Key('arrivalCityField')`. Au maximum ~4 items visibles ; au-delà, la liste interne scrolle (`ConstrainedBox(maxHeight: 4 * itemHeight)` + `ListView`). Au tap d'une suggestion : remplir le contrôleur, dispatcher `DepartureCityChanged`/`ArrivalCityChanged`, vider la liste, `FocusScope.of(context).unfocus()`. Style : conteneur `cs.surface`, bordure `cs.outline`, radius `DonyRadius.md`, item avec icône `DonyIcons.mapPin`.

- [ ] **Step 4: Lancer le test (succès attendu)**

Run: `flutter test test/features/matching/presentation/widgets/create_announcement/trajet_step_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/matching/ test/features/matching/
git commit -m "fix(matching): afficher les suggestions de ville en liste inline (B1)"
```

---

### Task 3: B2 — Keyboard avoidance

**Files:**
- Modify: `create_announcement_bottom_sheet.dart` (coquille du sheet)
- Modify: `create_announcement/trajet_step.dart`

- [ ] **Step 1: Lire la construction du sheet**

Lire `CreateAnnouncementBottomSheet.show()` (~52) et `_CreateAnnouncementContent` (~264) : vérifier `isScrollControlled` et la gestion de `viewInsets`.

- [ ] **Step 2: Padding clavier**

Garantir `isScrollControlled: true` sur le `showModalBottomSheet`/`DonyBottomSheet`. Envelopper le conteneur de contenu scrollable d'un `Padding(padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom), child: ...)` afin que le clavier pousse réellement la zone. Le footer sticky reste hors du scroll, ancré au-dessus du clavier.

- [ ] **Step 3: Amener le champ focus dans la zone visible**

Dans `trajet_step.dart`, sur chaque champ : attacher un `FocusNode` et, sur `focus gained`, appeler `Scrollable.ensureVisible(context, alignment: 0.1, duration: const Duration(milliseconds: 250))`.

- [ ] **Step 4: Validation manuelle**

Run: `flutter run --dart-define-from-file=env.dev.json`
Vérifier : clavier ouvert sur l'étape 1 → le champ saisi reste visible au-dessus du clavier, aucun champ masqué, footer ancré. Tester départ ET arrivée.

- [ ] **Step 5: Commit**

```bash
git add lib/features/matching/
git commit -m "fix(matching): corriger le keyboard avoidance du bottom sheet (B2)"
```

---

### Task 4: B3 — Texte rogné « Compte bancaire connecté »

**Files:**
- Read + Modify: `lib/features/payments/presentation/screens/payout_onboarding_screen.dart`

- [ ] **Step 1: Localiser le débordement**

Lire `payout_onboarding_screen.dart`, repérer le titre « Compte bancaire connecté » et le paragraphe d'intro qui le suit.

- [ ] **Step 2: Contraindre la largeur**

Garantir que le paragraphe et le titre sont dans une `Column(crossAxisAlignment: CrossAxisAlignment.start)` à l'intérieur d'un parent de largeur finie (`SingleChildScrollView` + `Padding` horizontal `DonySpacing.lg`). Si un `Row` ou un parent non borné cause le débordement, le remplacer par une `Column`/`Expanded`. Le `Text` ne doit avoir aucune largeur > écran.

- [ ] **Step 3: Validation manuelle**

Run: `flutter run --dart-define-from-file=env.dev.json`
Naviguer vers « Recevoir mes paiements ». Vérifier : aucun mot rogné à droite, aucun bandeau « RIGHT OVERFLOWED » dans la console.

- [ ] **Step 4: Commit**

```bash
git add lib/features/payments/
git commit -m "fix(payments): corriger le débordement du texte sur l'écran payout (B3)"
```

---

## PHASE 2 — Structure & cohérence

### Task 5: Modèle de capacité — `CapacityUnit.custom`

**Files:**
- Modify: `lib/features/matching/bloc/announcement_form_state.dart`
- Modify: `lib/features/matching/bloc/announcement_form_bloc.dart`
- Test: `test/features/matching/bloc/announcement_form_bloc_test.dart`

- [ ] **Step 1: Écrire les blocTest (échec attendu)**

Ajouter dans le fichier de test du bloc :

```dart
blocTest<AnnouncementFormBloc, AnnouncementFormState>(
  'sélectionner suitcase32kg fixe availableKg à 32',
  build: () => AnnouncementFormBloc(),
  act: (b) => b.add(const CapacityUnitChanged(CapacityUnit.suitcase32kg)),
  expect: () => [
    isA<AnnouncementFormState>()
        .having((s) => s.capacityUnit, 'unit', CapacityUnit.suitcase32kg)
        .having((s) => s.availableKg, 'kg', 32.0),
  ],
);

blocTest<AnnouncementFormBloc, AnnouncementFormState>(
  'sélectionner kgFree met availableKg à null',
  build: () => AnnouncementFormBloc(),
  act: (b) => b.add(const CapacityUnitChanged(CapacityUnit.kgFree)),
  expect: () => [
    isA<AnnouncementFormState>()
        .having((s) => s.capacityUnit, 'unit', CapacityUnit.kgFree)
        .having((s) => s.availableKg, 'kg', null),
  ],
);

blocTest<AnnouncementFormBloc, AnnouncementFormState>(
  'sélectionner custom puis régler le slider met availableKg',
  build: () => AnnouncementFormBloc(),
  act: (b) => b
    ..add(const CapacityUnitChanged(CapacityUnit.custom))
    ..add(const AvailableKgChanged(15)),
  expect: () => [
    isA<AnnouncementFormState>()
        .having((s) => s.capacityUnit, 'unit', CapacityUnit.custom),
    isA<AnnouncementFormState>().having((s) => s.availableKg, 'kg', 15.0),
  ],
);

test('custom.toWire vaut KG_EXACT', () {
  expect(CapacityUnit.custom.toWire(), 'KG_EXACT');
});
```

- [ ] **Step 2: Lancer (échec attendu)**

Run: `flutter test test/features/matching/bloc/announcement_form_bloc_test.dart`
Expected: FAIL (`CapacityUnit.custom` n'existe pas).

- [ ] **Step 3: Étendre l'enum**

Dans `announcement_form_state.dart`, modifier l'enum et ses extensions :

```dart
enum CapacityUnit { suitcase23kg, suitcase32kg, kgFree, custom }
```

Dans `extension CapacityUnitWire`, ajouter les branches `custom` :
- `toWire()` → `case CapacityUnit.custom: return 'KG_EXACT';`
- `label` → `case CapacityUnit.custom: return 'Personnalisé';`
- `maxKg` → `case CapacityUnit.custom: return 30.0;`

- [ ] **Step 4: Rendre `availableKg` nullable dans `copyWith`**

Toujours dans `announcement_form_state.dart`, remplacer le paramètre `double? availableKg` de `copyWith` par un getter (même pattern que `priceWarningGetter`) :

```dart
// signature
double? Function()? availableKgGetter,
// corps
availableKg: availableKgGetter != null ? availableKgGetter() : this.availableKg,
```

- [ ] **Step 5: Logique de capacité dans le bloc**

Dans `announcement_form_bloc.dart`, remplacer `_onCapacityUnitChanged` :

```dart
void _onCapacityUnitChanged(
  CapacityUnitChanged event,
  Emitter<AnnouncementFormState> emit,
) {
  switch (event.unit) {
    case CapacityUnit.suitcase23kg:
    case CapacityUnit.suitcase32kg:
      emit(state.copyWith(
        capacityUnit: event.unit,
        availableKgGetter: () => event.unit.maxKg,
      ));
    case CapacityUnit.kgFree:
      emit(state.copyWith(
        capacityUnit: event.unit,
        availableKgGetter: () => null,
      ));
    case CapacityUnit.custom:
      emit(state.copyWith(capacityUnit: event.unit));
  }
}
```

- [ ] **Step 6: Lancer (succès attendu)**

Run: `flutter test test/features/matching/bloc/announcement_form_bloc_test.dart`
Expected: PASS. Run aussi `flutter analyze` (les `switch` exhaustifs sur `CapacityUnit` ailleurs dans le code signaleront le cas `custom` manquant — les corriger).

- [ ] **Step 7: Commit**

```bash
git add lib/features/matching/ test/features/matching/
git commit -m "feat(matching): ajouter CapacityUnit.custom au modèle de capacité (M2)"
```

---

### Task 6: `DonyTextField` — variante tappable (champ unifié)

**Files:**
- Modify: `lib/core/design/widgets/dony_text_field.dart`
- Test: `test/core/design/widgets/dony_text_field_test.dart`

- [ ] **Step 1: Écrire le widget test (échec attendu)**

```dart
testWidgets('DonyTextField.tappable affiche la valeur et déclenche onTap',
    (tester) async {
  var tapped = false;
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: DonyTextField.tappable(
        label: 'Date de départ',
        value: 'jeu. 21 mai 2026',
        prefixIcon: Icons.calendar_today,
        onTap: () => tapped = true,
      ),
    ),
  ));
  expect(find.text('jeu. 21 mai 2026'), findsOneWidget);
  await tester.tap(find.text('jeu. 21 mai 2026'));
  expect(tapped, isTrue);
});
```

- [ ] **Step 2: Lancer (échec attendu)**

Run: `flutter test test/core/design/widgets/dony_text_field_test.dart`
Expected: FAIL (`tappable` n'existe pas).

- [ ] **Step 3: Ajouter le constructeur nommé `tappable`**

Dans `dony_text_field.dart`, ajouter un constructeur nommé `DonyTextField.tappable({label, value, prefixIcon, onTap, trailing})` et, dans `build()`, brancher : si mode tappable → rendre un `InkWell(onTap: onTap)` enveloppant un conteneur au **même habillage** que la variante texte (même `decoration`, radius `DonyRadius.md`, `contentPadding`, `prefixIcon`), affichant `value` (ou `label` grisé si `value` null) et un `trailing` optionnel (chevron). Réutiliser la décoration partagée pour ne pas diverger visuellement de la variante texte.

- [ ] **Step 4: Lancer (succès attendu)**

Run: `flutter test test/core/design/widgets/dony_text_field_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/core/design/ test/core/design/
git commit -m "feat(design): variante tappable de DonyTextField pour champs picker (M4)"
```

---

### Task 7: `capacity_control.dart` — contrôle 4 chips + slider

**Files:**
- Create: `create_announcement/capacity_control.dart`
- Delete: `lib/features/matching/presentation/widgets/capacity_selector.dart`
- Test: `test/features/matching/presentation/widgets/create_announcement/capacity_control_test.dart`

- [ ] **Step 1: Écrire les widget tests (échec attendu)**

```dart
void main() {
  Widget host() => /* MaterialApp + BlocProvider<AnnouncementFormBloc> + CapacityControl */;

  testWidgets('4 chips affichés', (tester) async {
    await tester.pumpWidget(host());
    expect(find.text('1 valise · 23 kg'), findsOneWidget);
    expect(find.text('Personnalisé'), findsOneWidget);
  });

  testWidgets('preset valise → carte de confirmation, pas de slider',
      (tester) async {
    await tester.pumpWidget(host());
    await tester.tap(find.text('1 valise · 23 kg'));
    await tester.pump();
    expect(find.textContaining('23 kg'), findsWidgets);
    expect(find.byType(Slider), findsNothing);
  });

  testWidgets('Personnalisé → slider visible', (tester) async {
    await tester.pumpWidget(host());
    await tester.tap(find.text('Personnalisé'));
    await tester.pump();
    expect(find.byType(Slider), findsOneWidget);
  });
}
```

- [ ] **Step 2: Lancer (échec attendu)**

Run: `flutter test test/features/matching/presentation/widgets/create_announcement/capacity_control_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implémenter `CapacityControl`**

Create `create_announcement/capacity_control.dart` :

```dart
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/design/dony_icons.dart';
import 'package:dony/features/matching/bloc/announcement_form_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_form_event.dart';
import 'package:dony/features/matching/bloc/announcement_form_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Contrôle de capacité : 4 chips single-select, slider en mode custom.
class CapacityControl extends StatelessWidget {
  const CapacityControl({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return BlocBuilder<AnnouncementFormBloc, AnnouncementFormState>(
      buildWhen: (p, c) =>
          p.capacityUnit != c.capacityUnit || p.availableKg != c.availableKg,
      builder: (context, state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Capacité disponible', style: tt.titleMedium),
            const SizedBox(height: DonySpacing.sm),
            Wrap(
              spacing: DonySpacing.sm,
              runSpacing: DonySpacing.sm,
              children: CapacityUnit.values.map((u) {
                final selected = state.capacityUnit == u;
                return GestureDetector(
                  onTap: () => context
                      .read<AnnouncementFormBloc>()
                      .add(CapacityUnitChanged(u)),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: DonySpacing.base, vertical: DonySpacing.sm),
                    decoration: BoxDecoration(
                      color: selected ? cs.primary : cs.surface,
                      borderRadius: BorderRadius.circular(DonyRadius.xl),
                      border: Border.all(
                          color: selected ? cs.primary : cs.outline),
                    ),
                    child: Text(
                      u.label,
                      style: tt.labelLarge?.copyWith(
                        color: selected ? cs.onPrimary : cs.onSurface,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: DonySpacing.md),
            _buildBody(context, state, cs, tt),
          ],
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, AnnouncementFormState state,
      ColorScheme cs, TextTheme tt) {
    switch (state.capacityUnit) {
      case CapacityUnit.suitcase23kg:
      case CapacityUnit.suitcase32kg:
        return _InfoCard(
          icon: DonyIcons.suitcase,
          title: 'Vous offrez ${state.capacityUnit.maxKg!.toInt()} kg',
          subtitle: 'Une valise standard en soute',
        );
      case CapacityUnit.kgFree:
        return _InfoCard(
          icon: DonyIcons.infinity,
          title: 'Sans limite précise',
          subtitle: 'L\'expéditeur verra « kilo disponible »',
        );
      case CapacityUnit.custom:
        final kg = (state.availableKg ?? 1).clamp(1, 30).toDouble();
        return Container(
          padding: const EdgeInsets.all(DonySpacing.base),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(DonyRadius.card),
            border: Border.all(color: cs.outline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Vous offrez', style: tt.titleMedium),
                  Text('${kg.toInt()} kg',
                      style: tt.headlineMedium?.copyWith(color: cs.primary)),
                ],
              ),
              Slider(
                value: kg,
                min: 1,
                max: 30,
                divisions: 29,
                onChanged: (v) => context
                    .read<AnnouncementFormBloc>()
                    .add(AvailableKgChanged(v)),
              ),
            ],
          ),
        );
    }
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard(
      {required this.icon, required this.title, required this.subtitle});
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(DonySpacing.base),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: cs.outline),
      ),
      child: Row(
        children: [
          Icon(icon, color: cs.primary, size: 24),
          const SizedBox(width: DonySpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: tt.titleMedium),
                Text(subtitle,
                    style: tt.bodySmall
                        ?.copyWith(color: cs.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Lancer (succès attendu)**

Run: `flutter test test/features/matching/presentation/widgets/create_announcement/capacity_control_test.dart`
Expected: PASS.

- [ ] **Step 5: Supprimer l'ancien sélecteur**

Run: `git rm lib/features/matching/presentation/widgets/capacity_selector.dart`
(L'intégration au pas de l'étape 2 se fait en Task 8 — l'import cassé sera résolu là.)

- [ ] **Step 6: Commit**

```bash
git add lib/features/matching/ test/features/matching/
git commit -m "feat(matching): contrôle de capacité 4 chips + slider (M2, P7)"
```

---

### Task 8: Extraire `lieux_capacite_step.dart` + intégrer `CapacityControl`

**Files:**
- Read first: `create_announcement_bottom_sheet.dart` (zone étape 2 + `_buildKgFreeDisplay`)
- Create: `create_announcement/lieux_capacite_step.dart`
- Modify: `create_announcement_bottom_sheet.dart`

- [ ] **Step 1: Lire la zone étape 2**

Identifier dans `_buildForm` le bloc de l'étape 2 (lieux de remise/récupération + capacité) et `_buildKgFreeDisplay`.

- [ ] **Step 2: Créer le widget extrait**

Create `create_announcement/lieux_capacite_step.dart` : widget `LieuxCapaciteStep`. Coller les champs lieux de remise/récupération + le lien « Utiliser ma position actuelle », puis remplacer **tout l'ancien bloc capacité** (`capacity_selector` + `_buildKgFreeDisplay` + slider) par `const CapacityControl()`.

- [ ] **Step 3: Brancher dans la coquille**

Dans `create_announcement_bottom_sheet.dart`, remplacer le bloc étape 2 par `LieuxCapaciteStep(...)`. Supprimer l'import et les usages de `capacity_selector.dart` et `_buildKgFreeDisplay`.

- [ ] **Step 4: Vérifier**

Run: `flutter analyze`
Expected: `No issues found!` (plus aucune référence à `capacity_selector`).
Run: `flutter test test/features/matching/`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/matching/
git commit -m "refactor(matching): extraire LieuxCapaciteStep et intégrer CapacityControl"
```

---

### Task 9: Extraire `prix_conditions_step.dart`

**Files:**
- Read first: `create_announcement_bottom_sheet.dart` (zone étape 3)
- Create: `create_announcement/prix_conditions_step.dart`
- Modify: `create_announcement_bottom_sheet.dart`

- [ ] **Step 1: Lire la zone étape 3**

Identifier le bloc étape 3 (prix/kg, estimation, modes de paiement, ce que j'accepte/refuse, note).

- [ ] **Step 2: Créer le widget extrait**

Create `create_announcement/prix_conditions_step.dart` : widget `PrixConditionsStep`, contenu de l'étape 3 collé à l'identique.

- [ ] **Step 3: Brancher dans la coquille**

Remplacer le bloc étape 3 par `PrixConditionsStep(...)` dans `create_announcement_bottom_sheet.dart`.

- [ ] **Step 4: Vérifier**

Run: `flutter analyze && flutter test test/features/matching/`
Expected: `No issues found!` + tests PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/matching/
git commit -m "refactor(matching): extraire PrixConditionsStep du bottom sheet"
```

---

### Task 10: M4 + M5 — Champ unifié et marquage requis sur l'étape 1

**Files:**
- Modify: `create_announcement/trajet_step.dart`

- [ ] **Step 1: Appliquer le champ unifié**

Dans `trajet_step.dart`, remplacer les champs hétérogènes par `DonyTextField` :
- Ville départ / arrivée → `DonyTextField` (variante texte), `prefixIcon` = `DonyIcons.departureCity` / `DonyIcons.arrivalCity`.
- Heure départ / arrivée → `DonyTextField.tappable` (ouvre le time picker), `prefixIcon` = `DonyIcons.time`, `trailing` = chevron, label suffixé « (optionnel) ».
- Date de départ → `DonyTextField.tappable` (ouvre le date picker), `prefixIcon` = `DonyIcons.date`.

- [ ] **Step 2: Marquer les champs requis**

Ajouter ` *` (astérisque `cs.error`) au label de : Ville de départ, Ville d'arrivée, Date de départ. Les heures restent « (optionnel) ».

- [ ] **Step 3: Vérifier**

Run: `flutter analyze && flutter test test/features/matching/presentation/widgets/create_announcement/trajet_step_test.dart`
Expected: `No issues found!` + PASS (adapter les clés/finders du test si besoin).

- [ ] **Step 4: Validation manuelle**

Run: `flutter run --dart-define-from-file=env.dev.json`
Vérifier l'étape 1 conforme à `maquettes/v6/15-33-49` : champs au même habillage, `*` sur les requis.

- [ ] **Step 5: Commit**

```bash
git add lib/features/matching/ test/features/matching/
git commit -m "feat(matching): champ unifié et marquage requis sur l'étape 1 (M4, M5)"
```

---

### Task 11: M1 + M3 — Dimensionnement au contenu et marge du footer

**Files:**
- Modify: `create_announcement_bottom_sheet.dart` (coquille)

- [ ] **Step 1: Dimensionnement au contenu (M1)**

Dans la coquille : retirer toute hauteur fixe / `Spacer` qui gonfle le sheet. Le contenu scrollable utilise `MainAxisSize.min` ; le sheet est plafonné via `constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.92)`. Étapes courtes → pas de zone morte.

- [ ] **Step 2: Marge du footer (M3)**

La zone du footer sticky est enveloppée d'un `SafeArea(top: false)` + `Padding(padding: EdgeInsets.symmetric(horizontal: DonySpacing.lg))`. Le(s) bouton(s) ne touchent jamais les bords.

- [ ] **Step 3: Validation manuelle**

Run: `flutter run --dart-define-from-file=env.dev.json`
Vérifier : aucun grand vide blanc sur les étapes 1 et 2 ; bouton « Continuer » avec marge latérale, non rogné.

- [ ] **Step 4: Commit**

```bash
git add lib/features/matching/
git commit -m "fix(matching): sheet dimensionné au contenu et footer avec marge (M1, M3)"
```

---

## PHASE 3 — Polish

### Task 12: P1 + P2 + P6 — Libellés, stepper, flèches

**Files:**
- Modify: `create_announcement_bottom_sheet.dart` (`_SectionLabel`, `_StepperHeader`, footer)
- Modify: les 3 fichiers `*_step.dart`

- [ ] **Step 1: Libellés de section (P1)**

Repérer `_SectionLabel` (~2514) : remplacer le style MAJUSCULES (`labelMedium` uppercase / `letterSpacing` élevé) par `titleMedium` (casse normale, w600). Vérifier que toutes les sections (`Trajet`, `Lieux de remise`, `Capacité disponible`, `Prix par kg`, `Modes de paiement acceptés`, `Ce que j'accepte`, `Ce que je refuse`, `Note aux expéditeurs`) passent en casse normale.

- [ ] **Step 2: Libellés du stepper (P2)**

Dans `_StepperHeader` (~2723) : libellés complets « Trajet », « Lieux & capacité », « Prix & conditions ».

- [ ] **Step 3: Flèches en icône (P6)**

Dans le footer et les boutons « Continuer »/« Aperçu »/« Retour » : remplacer la flèche présente dans la chaîne de texte par le paramètre `icon:` de `DonyButton` (`DonyIcons.arrowRight` / `DonyIcons.back`). Le `Text` ne contient plus de « → ».

- [ ] **Step 4: Vérifier**

Run: `flutter analyze && flutter test test/features/matching/`
Expected: `No issues found!` + PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/matching/
git commit -m "style(matching): libellés en casse normale, stepper complet, flèches icône (P1, P2, P6)"
```

---

### Task 13: P3 + P4 — Couleur arrivée et icône date

**Files:**
- Modify: `create_announcement/trajet_step.dart`
- Modify: `create_announcement/lieux_capacite_step.dart`

- [ ] **Step 1: Couleur d'arrivée (P3)**

Pour toutes les icônes « arrivée » (ville d'arrivée, heure d'arrivée, lieu de récupération) : utiliser `Theme.of(context).colorScheme.secondary` (terracotta `#D96A3A`, déjà brightness-aware) au lieu de tout orange vif. Les icônes « départ » utilisent `cs.primary`.

- [ ] **Step 2: Icône date (P4)**

L'icône `DonyIcons.date` du champ « Date de départ » prend `cs.primary` (couleur « départ »), pas une couleur neutre.

- [ ] **Step 3: Vérifier clair + sombre**

Run: `flutter run --dart-define-from-file=env.dev.json`
Vérifier en thème clair **et** sombre (réglage OS) : départ en bleu, arrivée en terracotta, aucune couleur criarde, aucun `Color(0xFF…)` hardcodé.

- [ ] **Step 4: Commit**

```bash
git add lib/features/matching/
git commit -m "style(matching): couleur arrivée terracotta et icône date départ (P3, P4)"
```

---

### Task 14: P5 — Footer à hauteur constante

**Files:**
- Modify: `create_announcement_bottom_sheet.dart` (footer)

- [ ] **Step 1: Stabiliser le footer**

Le footer a une hauteur constante sur les 3 étapes. Étape 1 : un seul `DonyButton` « Continuer » pleine largeur. Étapes 2-3 : `Row` `[DonyButton secondary « Retour »]` + `[DonyButton primary « Continuer/Aperçu »]`. La hauteur du conteneur footer ne change pas d'une étape à l'autre (même padding vertical, même hauteur de bouton 52) — aucun saut de mise en page lors de la navigation entre étapes.

- [ ] **Step 2: Validation manuelle**

Run: `flutter run --dart-define-from-file=env.dev.json`
Naviguer étape 1 → 2 → 3 : vérifier qu'aucun saut vertical du footer ne se produit.

- [ ] **Step 3: Commit**

```bash
git add lib/features/matching/
git commit -m "style(matching): footer à hauteur constante entre les étapes (P5)"
```

---

### Task 15: Validation finale & couverture

**Files:** —

- [ ] **Step 1: Suite complète**

Run: `flutter analyze`
Expected: `No issues found!`
Run: `flutter test --coverage`
Expected: tous les tests PASS.

- [ ] **Step 2: Couverture ≥ 90 %**

Run: `genhtml coverage/lcov.info -o coverage/html`
Ouvrir `coverage/html/index.html`. Si la couverture des fichiers `create_announcement/`, `dony_text_field.dart`, `announcement_form_bloc.dart` est < 90 %, ajouter des widget/bloc tests jusqu'à atteindre le seuil.

- [ ] **Step 3: Recette manuelle complète**

Run: `flutter run --dart-define-from-file=env.dev.json`
Parcourir le checklist du spec §10 : clavier sur les 3 étapes, autocomplétion ville, bouton non rogné, aucun débordement horizontal, rendu clair + sombre, conformité aux 9 maquettes `v6`.

- [ ] **Step 4: Commit final éventuel**

```bash
git add test/
git commit -m "test(matching): compléter la couverture du flux de publication"
```

---

## Auto-revue (couverture du spec)

- §5 Icônes Phosphor → Task 0 ✓
- §6 Modèle capacité `custom` → Task 5 ✓
- §7 B1 autocomplétion → Task 2 ✓ · B2 clavier → Task 3 ✓ · B3 texte rogné → Task 4 ✓
- §8 M1 vide → Task 11 ✓ · M2 capacité → Tasks 5+7+8 ✓ · M3 marge → Task 11 ✓ · M4 champ unifié → Tasks 6+10 ✓ · M5 requis → Task 10 ✓
- §9 P1 → Task 12 ✓ · P2 → Task 12 ✓ · P3 → Task 13 ✓ · P4 → Task 13 ✓ · P5 → Task 14 ✓ · P6 → Task 12 ✓ · P7 → Task 7 ✓
- §4 Découpage fichiers → Tasks 1, 8, 9 ✓
- §10 Tests & couverture → présents par tâche + Task 15 ✓

**Point ouvert non bloquant pour le plan :** wire `KG_EXACT` pour `custom` (Task 5 Step 3) — à confirmer côté backend ; repli documenté dans le spec §6.
