# Annonces urgentes — Plan d'implémentation FRONTEND (dony_app)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Badge « 🔥 Urgent » sur les cartes trajet + demande, et chip de filtre binaire « Urgent » (serveur) qui n'affiche que les publications urgentes de l'onglet courant.

**Architecture:** Le seuil est chargé du backend au démarrage (comme `dony.commission.rate`) dans un helper `dony_urgency`. Le badge lit le champ `urgent` renvoyé par l'API (repli : calcul local sur la date + seuil). Le chip pilote un booléen `_urgentOnly` passé en param `urgent=true` aux recherches trajets/demandes selon l'onglet.

**Tech Stack:** Flutter, flutter_bloc, Dio, GetIt, flutter_animate.

## Global Constraints

- Seuil par défaut **3** jours (repli local si le backend n'a pas répondu).
- Urgent (repli local) : `today ≤ date ≤ today + urgencyThresholdDays`.
- Source de vérité du badge : champ `urgent` de l'API ; repli local seulement si absent.
- Design system : `DonyColors.urgencyRed` (`#EF4444`, déjà défini), tokens `DonySpacing`/`DonyRadius`, jamais de couleur/taille en dur.
- Repo dony_app : `/Users/aboubakardiakite/Desktop/dony/dony_app`. Branche : `feature/urgent-announcements`.
- Tests : `flutter test` vert + `flutter analyze` 0 erreur avant chaque commit.
- BLoC (pas de setState), GoRouter (pas de Navigator.push).

---

### Task 1: Helper de seuil + chargement au démarrage

**Files:**
- Create: `lib/core/urgency/dony_urgency.dart`
- Modify: `lib/features/config/data/config_repository.dart:4-21`
- Modify: `lib/features/config/data/config_datasource.dart:8-12`
- Modify: `lib/main.dart:131-143`
- Create: `test/core/urgency/dony_urgency_test.dart`
- Modify: `test/features/config/data/config_repository_test.dart`

**Interfaces:**
- Produces: `int get urgencyThresholdDays` ; `void setUrgencyThresholdDays(int)` ; `bool isUrgentDate(DateTime date)` ; `IConfigRepository.getUrgencyThresholdDays()`.

- [ ] **Step 1: Écrire le test du helper (échoue)**

`test/core/urgency/dony_urgency_test.dart` :

```dart
import 'package:dony/core/urgency/dony_urgency.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() => setUrgencyThresholdDays(kUrgencyThresholdDaysDefault));

  test('seuil par défaut = 3', () {
    expect(urgencyThresholdDays, 3);
  });

  test('setUrgencyThresholdDays ignore les valeurs aberrantes', () {
    setUrgencyThresholdDays(0);
    expect(urgencyThresholdDays, 3);
    setUrgencyThresholdDays(-1);
    expect(urgencyThresholdDays, 3);
    setUrgencyThresholdDays(90);
    expect(urgencyThresholdDays, 3);
    setUrgencyThresholdDays(7);
    expect(urgencyThresholdDays, 7);
  });

  test('isUrgentDate : bornes exactes', () {
    setUrgencyThresholdDays(3);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    expect(isUrgentDate(today), isTrue);
    expect(isUrgentDate(today.add(const Duration(days: 3))), isTrue);
    expect(isUrgentDate(today.add(const Duration(days: 4))), isFalse);
    expect(isUrgentDate(today.subtract(const Duration(days: 1))), isFalse);
  });
}
```

- [ ] **Step 2: Lancer — doit échouer**

Run: `flutter test test/core/urgency/dony_urgency_test.dart`
Expected: FAIL (fichier absent).

- [ ] **Step 3: Créer le helper**

`lib/core/urgency/dony_urgency.dart` :

```dart
/// Seuil d'urgence (jours) : une publication est « urgente » si sa date clé
/// tombe dans les [urgencyThresholdDays] prochains jours (aujourd'hui inclus).
/// SOURCE UNIQUE du seuil : backend (`dony.urgency.threshold-days`), chargé au
/// démarrage. Repli sur [kUrgencyThresholdDaysDefault] tant qu'il n'est pas chargé.
const int kUrgencyThresholdDaysDefault = 3;

int _urgencyThresholdDays = kUrgencyThresholdDaysDefault;

int get urgencyThresholdDays => _urgencyThresholdDays;

/// Met à jour le seuil au démarrage. Ignore les valeurs aberrantes (hors ]0,60]).
void setUrgencyThresholdDays(int days) {
  if (days > 0 && days <= 60) _urgencyThresholdDays = days;
}

/// Vrai si [date] tombe entre aujourd'hui et aujourd'hui + seuil (bornes incluses).
bool isUrgentDate(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final d = DateTime(date.year, date.month, date.day);
  final diff = d.difference(today).inDays;
  return diff >= 0 && diff <= _urgencyThresholdDays;
}
```

- [ ] **Step 4: Lancer — doit passer**

Run: `flutter test test/core/urgency/dony_urgency_test.dart`
Expected: PASS.

- [ ] **Step 5: Étendre IConfigRepository + datasource**

Dans `config_repository.dart`, ajouter à l'interface + l'impl :

```dart
// interface
Future<int> getUrgencyThresholdDays();

// impl ConfigRepository
@override
Future<int> getUrgencyThresholdDays() async {
  return _datasource.getUrgencyThresholdDays();
}
```

Dans `config_datasource.dart` :

```dart
Future<int> getUrgencyThresholdDays() async {
  final response = await _client.dio.get('/config/urgency-threshold');
  final data = response.data as Map<String, dynamic>;
  return (data['thresholdDays'] as num).toInt();
}
```

- [ ] **Step 6: Charger au démarrage**

Dans `main.dart`, à côté de `_loadDonyCommissionRate` :

```dart
unawaited(_loadUrgencyThreshold());

Future<void> _loadUrgencyThreshold() async {
  try {
    setUrgencyThresholdDays(
      await getIt<IConfigRepository>().getUrgencyThresholdDays(),
    );
  } catch (_) {
    // Repli sur kUrgencyThresholdDaysDefault — non bloquant.
  }
}
```

Ajouter l'appel `unawaited(_loadUrgencyThreshold());` juste après `unawaited(_loadDonyCommissionRate());`. Importer `dony_urgency.dart`.

- [ ] **Step 7: Mettre à jour le mock du repo dans les tests config**

Si `config_repository_test.dart` mocke `IConfigRepository`, ajouter le stub `getUrgencyThresholdDays()` pour éviter les erreurs de compilation. Vérifier aussi les autres mocks de `IConfigRepository` du projet (`grep -r "implements IConfigRepository\|MockConfigRepository" test lib`).

- [ ] **Step 8: analyze + commit**

Run: `flutter analyze lib/core/urgency lib/features/config lib/main.dart` → 0 erreur.

```bash
git add lib/core/urgency lib/features/config lib/main.dart test/core/urgency test/features/config
git commit -m "feat(urgency): helper de seuil + chargement backend au démarrage"
```

---

### Task 2: Champ `urgent` dans les modèles

**Files:**
- Modify: `lib/features/matching/data/models/announcement_model.dart:95-230`
- Modify: `lib/features/package_request/data/models/package_request_search_item.dart:8-166`
- Modify: `test/features/matching/data/bid_model_test.dart` ou le test du modèle annonce
- Modify: `test/features/package_request/...` (test du modèle demande)

**Interfaces:**
- Produces: `AnnouncementModel.isUrgent` → `bool` ; `PackageRequestSearchItem.isUrgent` → `bool`.

- [ ] **Step 1: Test modèle annonce (échoue)**

Dans le test du modèle annonce (chercher `AnnouncementModel.fromJson` dans test/) :

```dart
test('urgent depuis le JSON prime sur le calcul local', () {
  final json = { /* champs requis */, 'urgent': true };
  final m = AnnouncementModel.fromJson(json);
  expect(m.isUrgent, isTrue);
});

test('urgent absent → repli sur la date', () {
  // departureDate = aujourd'hui + 1 → isUrgent true (seuil défaut 3)
});
```

- [ ] **Step 2: Ajouter le champ + getter**

Dans `announcement_model.dart` : ajouter `final bool? urgent;` au constructeur, `urgent: json['urgent'] as bool?` dans `fromJson`, et le getter :

```dart
import 'package:dony/core/urgency/dony_urgency.dart';

bool get isUrgent => urgent ?? isUrgentDate(departureDate);
```

Répercuter `urgent` dans `copyWith`/`toJson` s'ils existent (garder le champ optionnel).

- [ ] **Step 3: Idem pour PackageRequestSearchItem**

Dans `package_request_search_item.dart` : `final bool? urgent;`, `urgent: json['urgent'] as bool?`, et :

```dart
bool get isUrgent => urgent ?? isUrgentDate(desiredDate);
```

- [ ] **Step 4: Lancer les tests modèles + analyze + commit**

Run: `flutter test test/features/matching test/features/package_request` (cibler les tests modèles).
Expected: PASS.

```bash
git add lib/features/matching/data/models/announcement_model.dart lib/features/package_request/data/models/package_request_search_item.dart test/
git commit -m "feat(urgency): champ urgent + getter isUrgent sur les modèles"
```

---

### Task 3: Badge « 🔥 Urgent » sur les cartes

**Files:**
- Create: `lib/core/design/widgets/dony_urgent_badge.dart`
- Modify: `lib/features/matching/presentation/widgets/traveler_card.dart:210-229`
- Modify: `lib/features/package_request/presentation/widgets/package_request_list_card.dart` (zone badges)
- Modify: `test/features/matching/presentation/widgets/traveler_card_test.dart`

**Interfaces:**
- Consumes: `AnnouncementModel.isUrgent`, `PackageRequestSearchItem.isUrgent` (Task 2).
- Produces: `DonyUrgentBadge` widget.

- [ ] **Step 1: Créer le badge**

`lib/core/design/widgets/dony_urgent_badge.dart` :

```dart
import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';

/// Pill rouge « 🔥 Urgent » pour les publications dont la date clé est proche.
class DonyUrgentBadge extends StatelessWidget {
  const DonyUrgentBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: DonyColors.urgencyRed.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(DonyRadius.full),
      ),
      child: Text(
        '🔥 Urgent',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: DonyColors.urgencyRed,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}
```

Exporter depuis `lib/core/design/design_system.dart` (ajouter la ligne `export`).

- [ ] **Step 2: Test badge sur TravelerCard (échoue)**

Dans `traveler_card_test.dart` :

```dart
testWidgets('affiche le badge Urgent quand annonce.isUrgent', (tester) async {
  // pump TravelerCard avec une annonce departureDate = aujourd'hui + 1
  expect(find.text('🔥 Urgent'), findsOneWidget);
});

testWidgets('pas de badge Urgent si départ lointain', (tester) async {
  // departureDate = aujourd'hui + 20
  expect(find.text('🔥 Urgent'), findsNothing);
});
```

- [ ] **Step 3: Insérer le badge dans TravelerCard**

Dans `traveler_card.dart`, dans le `Wrap` des badges (lignes 210-229), après `if (isProAccount) const _ProBadge(),` :

```dart
if (announcement.isUrgent) const DonyUrgentBadge(),
```

Importer `dony_urgent_badge.dart` (ou via `design_system.dart`).

- [ ] **Step 4: Insérer dans PackageRequestListCard**

Localiser la zone des badges/pills de `package_request_list_card.dart` (chercher un `Row`/`Wrap` d'en-tête) et ajouter `if (item.isUrgent) const DonyUrgentBadge(),`. Si aucune zone badge n'existe, ajouter une `Row` en tête de carte contenant uniquement le badge quand `item.isUrgent`.

- [ ] **Step 5: Lancer + analyze + commit**

Run: `flutter test test/features/matching/presentation/widgets/traveler_card_test.dart`
Expected: PASS. Puis `flutter analyze` sur les fichiers touchés → 0 erreur.

```bash
git add lib/core/design/widgets/dony_urgent_badge.dart lib/core/design/design_system.dart lib/features/matching/presentation/widgets/traveler_card.dart lib/features/package_request/presentation/widgets/package_request_list_card.dart test/
git commit -m "feat(urgency): badge 🔥 Urgent sur cartes trajet et demande"
```

---

### Task 4: Chip filtre « Urgent » (serveur, combiné à l'onglet)

**Files:**
- Modify: `lib/features/matching/data/models/search_params.dart` (ajouter `urgentOnly`)
- Modify: `lib/features/matching/data/datasources/announcement_remote_datasource.dart` (query `urgent`)
- Modify: `lib/features/matching/bloc/announcement_event.dart` (champ urgent sur l'event de recherche)
- Modify: `lib/features/package_request/data/...` (query `urgent` pour la recherche demandes)
- Modify: `lib/features/home/presentation/home_screen.dart` (état `_urgentOnly`, chip, dispatch)
- Modify: `test/features/home/presentation/home_screen_test.dart`

**Interfaces:**
- Consumes: seuil serveur (le filtre est appliqué côté back via `urgent=true`).
- Produces: chip togglable `_urgentOnly` → param `urgent=true` sur les 2 recherches.

- [ ] **Step 1: Ajouter `urgentOnly` à SearchParams**

Dans `search_params.dart` : `final bool urgentOnly;` (défaut `false`) au constructeur + `copyWith`. Dans la sérialisation en query params (là où les champs sont convertis pour Dio), ajouter `if (urgentOnly) 'urgent': 'true'`.

- [ ] **Step 2: Propager dans le datasource annonces**

Dans `announcement_remote_datasource.dart`, méthode de recherche : ajouter `if (params.urgentOnly) queryParameters['urgent'] = true;` (adapter au nom réel de la map de query).

- [ ] **Step 3: Propager dans la recherche demandes**

Repérer le datasource/bloc de recherche demandes (`PackageRequestSearchBloc` + son datasource). Ajouter un param `bool urgent` à l'event de recherche et au query (`'urgent': true`).

- [ ] **Step 4: État + chip dans home_screen**

Dans `_HomeScreenState` : ajouter `bool _urgentOnly = false;`. Incrémenter `_activeFilterCount` si `_urgentOnly`. Dans `_dispatchSearch()` et `_dispatchPackageRequestSearch()`, passer `urgentOnly: _urgentOnly` (annonces) / `urgent: _urgentOnly` (demandes).

Dans `_HomeFilterChipsRow` (et sa version parcels), ajouter un `_SmallChip` :

```dart
_SmallChip(
  label: 'Urgent',
  iconAsset: 'fire', // vérifier l'existence de l'asset ; sinon utiliser un emoji dans le label : '🔥 Urgent'
  isActive: urgentOnly,
  onTap: onUrgentToggle,
),
```

Passer `urgentOnly: _urgentOnly` et `onUrgentToggle: () { setState(() => _urgentOnly = !_urgentOnly); _dispatchSearch(); _dispatchPackageRequestSearch(); }` depuis `_filterChipsRow`.

Note : vérifier qu'un asset `fire` existe (`ls assets/icons | grep fire`). Sinon, mettre l'emoji 🔥 directement dans le `label` et ne pas passer `iconAsset`.

- [ ] **Step 5: Test toggle (échoue puis passe)**

Dans `home_screen_test.dart` :

```dart
testWidgets('le chip Urgent déclenche une recherche avec urgent=true', (tester) async {
  // pump home, tap le chip 'Urgent', vérifier que l'event de recherche
  // porte urgentOnly/urgent == true (via un mock bloc ou capture d'event).
});
```

- [ ] **Step 6: Lancer + analyze + commit**

Run: `flutter test test/features/home/presentation/home_screen_test.dart` → PASS. `flutter analyze` → 0 erreur.

```bash
git add lib/features/matching lib/features/package_request lib/features/home test/
git commit -m "feat(urgency): chip filtre Urgent (serveur) combiné à l'onglet"
```

---

### Task 5: Feedback à la création

**Files:**
- Modify: `lib/features/matching/presentation/widgets/create_announcement/trajet_step.dart:28-76`
- Modify: le step date du wizard package request (chercher `desiredDate` / `dateToleranceDays` dans `lib/features/package_request/presentation/`)
- Modify: tests widget correspondants

**Interfaces:**
- Consumes: `isUrgentDate(DateTime)` (Task 1).

- [ ] **Step 1: Feedback sous le date picker trajet**

Dans `trajet_step.dart`, après le champ date (utilise `departureDateNotifier`), afficher via `ValueListenableBuilder<DateTime?>` :

```dart
ValueListenableBuilder<DateTime?>(
  valueListenable: departureDateNotifier,
  builder: (context, date, _) {
    if (date == null || !isUrgentDate(date)) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: DonySpacing.xs),
      child: Text(
        '🔥 Départ proche — ce trajet sera signalé urgent',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: DonyColors.urgencyRed,
            ),
      ),
    );
  },
)
```

Importer `dony_urgency.dart` + `design_system.dart`.

- [ ] **Step 2: Feedback sous le date picker demande**

Même widget dans le step date de la demande, texte : `'🔥 Date proche — cette demande sera signalée urgente'`, basé sur la date souhaitée sélectionnée.

- [ ] **Step 3: Test widget (échoue puis passe)**

Test : sélectionner une date ≤ seuil → texte présent ; date lointaine → `SizedBox.shrink` (texte absent).

- [ ] **Step 4: Lancer + analyze + commit**

Run: `flutter test` (tests des steps). `flutter analyze` → 0 erreur.

```bash
git add lib/features/matching/presentation/widgets/create_announcement/trajet_step.dart lib/features/package_request/presentation test/
git commit -m "feat(urgency): feedback urgent à la création (trajet + demande)"
```

---

### Task 6: Vérification globale + push + PR

- [ ] **Step 1: Suite complète + analyze**

Run: `flutter test` → 4880+ verts, 0 rouge. `flutter analyze` → 0 erreur.

- [ ] **Step 2: Push + PR draft**

```bash
git push -u origin feature/urgent-announcements
gh pr create --draft --title "feat: badge + filtre Urgent (trajets + demandes)" --body "Badge 🔥 sur cartes trajet/demande (champ urgent API, repli local seuil), chip filtre binaire serveur combiné à l'onglet, feedback à la création. Seuil chargé de /config/urgency-threshold. Dépend de la PR back."
```

## Self-review effectué

- Couverture spec §4.1–4.6 : Task 1 (seuil), Task 2 (modèles), Task 3 (badge), Task 4 (chip filtre), Task 5 (feedback). ✓
- Types cohérents : `isUrgent` (getter modèles), `urgentOnly` (SearchParams), `isUrgentDate`/`urgencyThresholdDays` (helper) réutilisés partout. ✓
- Repli local documenté : `urgent ?? isUrgentDate(date)`. ✓
- Points à vérifier par l'implémenteur (marqués inline) : nom exact de la map de query params du datasource, existence de l'asset `fire`, zone badges de PackageRequestListCard.
