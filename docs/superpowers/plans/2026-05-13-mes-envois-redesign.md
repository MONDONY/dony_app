# Mes envois — Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remplacer l'écran "Mes envois" par une interface avec header sombre (#0A2540) intégrant les tabs "En cours / À venir / Passés", et un stepper de progression 4 étapes sur chaque card.

**Architecture:** Tout le code reste dans un seul fichier (`my_package_requests_screen.dart`). Aucun nouveau fichier. Aucune modification BLoC/repository. L'état des tabs est géré localement dans `_ListContentState` via un enum `_Tab`. Le header sombre est un widget privé `_DarkHeader` qui intègre le bouton retour, le titre, le compteur badge, et la `_TabRow`. Le stepper est un widget privé `_ProgressStepper` utilisé dans chaque `_RequestCard`.

**Tech Stack:** Flutter, flutter_animate, intl, design system dony (`DonySpacing`, `DonyRadius`, `DonyColors`, `DonyEmptyState`, `DonyMascotteType`, `cs.success`, `cs.warning`)

---

## Fichiers

| Fichier | Action |
|---------|--------|
| `lib/features/package_request/presentation/screens/sender/my_package_requests_screen.dart` | Réécriture complète |
| `test/features/package_request/presentation/screens/sender/my_package_requests_screen_test.dart` | Mise à jour tests |

---

## Mapping de référence

### Tabs → statuts filtrés

| Tab | Statuts inclus |
|-----|---------------|
| `_Tab.enCours` | `negotiating`, `accepted` |
| `_Tab.aVenir` | `open` |
| `_Tab.passes` | `completed`, `expired`, `cancelled` |

### Statut → étape active du stepper (`_activeStep`)

| Statut | Valeur retournée | Signification |
|--------|-----------------|---------------|
| `open` | 0 | "Publié" est l'étape active |
| `negotiating` | 1 | "Accepté" est l'étape active |
| `accepted` | 2 | "En route" est l'étape active |
| `completed` | 4 | Sentinelle : toutes les étapes sont "done" |
| `expired` / `cancelled` | -1 | Sentinelle : toutes les étapes grises |

### Statut → CTA label

| Statut | Label |
|--------|-------|
| `open` | `'Modifier →'` |
| `negotiating`, `accepted` | `'Voir →'` |
| `completed`, `expired`, `cancelled` | `'Détail →'` |

---

## Task 1 — Mettre à jour le fichier de tests

**Files:**
- Modify: `test/features/package_request/presentation/screens/sender/my_package_requests_screen_test.dart`

- [ ] **Step 1 : Supprimer les deux tests sur l'ancien footer**

Retirer les blocs `testWidgets` suivants (ils testent des textes qui n'existent plus dans le nouveau design) :
- `'affiche "En attente d\'offres…" dans le footer pour open'`
- `'affiche "Négociation en cours" dans le footer pour negotiating'`

- [ ] **Step 2 : Mettre à jour le test de liste globalement vide**

Le texte `'Tu n\'as encore rien envoyé'` disparaît — remplacer par `'Aucun envoi en cours'` (tab par défaut "En cours" vide) :

```dart
testWidgets('affiche empty state "Aucun envoi en cours" quand la liste est vide',
    (tester) async {
  when(() => bloc.state).thenReturn(const PackageRequestState(
    status: PackageRequestListStatus.loaded,
    requests: [],
  ));
  await tester.pumpWidget(wrap());
  await tester.pumpAndSettle();
  expect(find.text('Aucun envoi en cours'), findsOneWidget);
});
```

- [ ] **Step 3 : Mettre à jour le badge OUVERTE (statut open → tab "À venir")**

Le badge `OUVERTE` est maintenant dans la tab "À venir". Ajouter le tap de navigation :

```dart
testWidgets('affiche le badge OUVERTE pour status=open', (tester) async {
  when(() => bloc.state).thenReturn(PackageRequestState(
    status: PackageRequestListStatus.loaded,
    requests: [_request(status: PackageRequestStatus.open)],
  ));
  await tester.pumpWidget(wrap());
  await tester.pumpAndSettle();
  await tester.tap(find.text('À venir'));
  await tester.pumpAndSettle();
  expect(find.text('OUVERTE'), findsOneWidget);
});
```

- [ ] **Step 4 : Mettre à jour le badge EXPIRÉE (statut expired → tab "Passés")**

```dart
testWidgets('affiche le badge EXPIRÉE pour status=expired', (tester) async {
  when(() => bloc.state).thenReturn(PackageRequestState(
    status: PackageRequestListStatus.loaded,
    requests: [_request(status: PackageRequestStatus.expired)],
  ));
  await tester.pumpWidget(wrap());
  await tester.pumpAndSettle();
  await tester.tap(find.text('Passés'));
  await tester.pumpAndSettle();
  expect(find.text('EXPIRÉE'), findsOneWidget);
});
```

- [ ] **Step 5 : Ajouter le test d'affichage des tabs**

```dart
testWidgets('affiche les trois onglets dans le header', (tester) async {
  when(() => bloc.state).thenReturn(PackageRequestState(
    status: PackageRequestListStatus.loaded,
    requests: [_request(status: PackageRequestStatus.negotiating)],
  ));
  await tester.pumpWidget(wrap());
  await tester.pumpAndSettle();
  expect(find.text('En cours'), findsOneWidget);
  expect(find.text('À venir'), findsOneWidget);
  expect(find.text('Passés'), findsOneWidget);
});
```

- [ ] **Step 6 : Ajouter les tests de filtrage par tab**

```dart
group('Filtrage par tab', () {
  testWidgets('tab "En cours" affiche negotiating et accepted, pas open',
      (tester) async {
    when(() => bloc.state).thenReturn(PackageRequestState(
      status: PackageRequestListStatus.loaded,
      requests: [
        _request(status: PackageRequestStatus.open),
        _request(status: PackageRequestStatus.negotiating),
        _request(status: PackageRequestStatus.accepted),
      ],
    ));
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
    // "En cours" est actif par défaut
    expect(find.text('NÉGOCIATION'), findsOneWidget);
    expect(find.text('ACCEPTÉE'), findsOneWidget);
    expect(find.text('OUVERTE'), findsNothing);
  });

  testWidgets('tab "À venir" affiche open uniquement', (tester) async {
    when(() => bloc.state).thenReturn(PackageRequestState(
      status: PackageRequestListStatus.loaded,
      requests: [
        _request(status: PackageRequestStatus.open),
        _request(status: PackageRequestStatus.negotiating),
      ],
    ));
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
    await tester.tap(find.text('À venir'));
    await tester.pumpAndSettle();
    expect(find.text('OUVERTE'), findsOneWidget);
    expect(find.text('NÉGOCIATION'), findsNothing);
  });

  testWidgets('tab "Passés" affiche completed et expired, pas open',
      (tester) async {
    when(() => bloc.state).thenReturn(PackageRequestState(
      status: PackageRequestListStatus.loaded,
      requests: [
        _request(status: PackageRequestStatus.completed),
        _request(status: PackageRequestStatus.expired),
        _request(status: PackageRequestStatus.open),
      ],
    ));
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Passés'));
    await tester.pumpAndSettle();
    expect(find.text('LIVRÉE'), findsOneWidget);
    expect(find.text('EXPIRÉE'), findsOneWidget);
    expect(find.text('OUVERTE'), findsNothing);
  });
});
```

- [ ] **Step 7 : Ajouter le test de présence des labels du stepper**

```dart
testWidgets('card affiche les 4 labels du stepper', (tester) async {
  when(() => bloc.state).thenReturn(PackageRequestState(
    status: PackageRequestListStatus.loaded,
    requests: [_request(status: PackageRequestStatus.negotiating)],
  ));
  // negotiating → tab "En cours" (défaut)
  await tester.pumpWidget(wrap());
  await tester.pumpAndSettle();
  expect(find.text('Publié'), findsOneWidget);
  expect(find.text('Accepté'), findsOneWidget);
  expect(find.text('En route'), findsOneWidget);
  expect(find.text('Livré'), findsOneWidget);
});
```

- [ ] **Step 8 : Ajouter les tests de CTA contextuel**

```dart
group('CTA contextuel', () {
  testWidgets('CTA "Modifier →" pour status=open', (tester) async {
    when(() => bloc.state).thenReturn(PackageRequestState(
      status: PackageRequestListStatus.loaded,
      requests: [_request(status: PackageRequestStatus.open)],
    ));
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
    await tester.tap(find.text('À venir'));
    await tester.pumpAndSettle();
    expect(find.text('Modifier →'), findsOneWidget);
  });

  testWidgets('CTA "Voir →" pour status=negotiating', (tester) async {
    when(() => bloc.state).thenReturn(PackageRequestState(
      status: PackageRequestListStatus.loaded,
      requests: [_request(status: PackageRequestStatus.negotiating)],
    ));
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
    expect(find.text('Voir →'), findsOneWidget);
  });

  testWidgets('CTA "Voir →" pour status=accepted', (tester) async {
    when(() => bloc.state).thenReturn(PackageRequestState(
      status: PackageRequestListStatus.loaded,
      requests: [_request(status: PackageRequestStatus.accepted)],
    ));
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
    expect(find.text('Voir →'), findsOneWidget);
  });

  testWidgets('CTA "Détail →" pour status=completed', (tester) async {
    when(() => bloc.state).thenReturn(PackageRequestState(
      status: PackageRequestListStatus.loaded,
      requests: [_request(status: PackageRequestStatus.completed)],
    ));
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Passés'));
    await tester.pumpAndSettle();
    expect(find.text('Détail →'), findsOneWidget);
  });
});
```

- [ ] **Step 9 : Ajouter les tests de empty state par tab**

```dart
group('Empty state par tab', () {
  testWidgets('tab "En cours" vide → "Aucun envoi en cours"', (tester) async {
    // Seul une demande open existe → tab "En cours" est vide
    when(() => bloc.state).thenReturn(PackageRequestState(
      status: PackageRequestListStatus.loaded,
      requests: [_request(status: PackageRequestStatus.open)],
    ));
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
    // "En cours" actif par défaut, aucun negotiating/accepted
    expect(find.text('Aucun envoi en cours'), findsOneWidget);
  });

  testWidgets('tab "À venir" vide → "Aucune demande ouverte"', (tester) async {
    when(() => bloc.state).thenReturn(PackageRequestState(
      status: PackageRequestListStatus.loaded,
      requests: [_request(status: PackageRequestStatus.negotiating)],
    ));
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
    await tester.tap(find.text('À venir'));
    await tester.pumpAndSettle();
    expect(find.text('Aucune demande ouverte'), findsOneWidget);
  });

  testWidgets('tab "Passés" vide → "Aucun historique"', (tester) async {
    when(() => bloc.state).thenReturn(PackageRequestState(
      status: PackageRequestListStatus.loaded,
      requests: [_request(status: PackageRequestStatus.open)],
    ));
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Passés'));
    await tester.pumpAndSettle();
    expect(find.text('Aucun historique'), findsOneWidget);
  });
});
```

- [ ] **Step 10 : Lancer les tests pour confirmer les échecs attendus**

```bash
cd /home/a-diakite/Desktop/MyProject/my_app/dony_app
flutter test test/features/package_request/presentation/screens/sender/my_package_requests_screen_test.dart --reporter expanded
```

Résultat attendu : les nouveaux tests échouent (textes absents de l'ancienne UI). Les tests existants (loading, error, route text) peuvent encore passer ou échouer.

- [ ] **Step 11 : Commit de base des tests**

```bash
cd /home/a-diakite/Desktop/MyProject/my_app/dony_app
git add test/features/package_request/presentation/screens/sender/my_package_requests_screen_test.dart
git commit -m "test(mes-envois): mise à jour tests pour redesign — tabs, stepper, CTA, empty states"
```

---

## Task 2 — Enum `_Tab` + fonctions utilitaires top-level

**Files:**
- Modify: `lib/features/package_request/presentation/screens/sender/my_package_requests_screen.dart`

- [ ] **Step 1 : Ajouter l'import go_router**

En haut du fichier, après les imports existants, ajouter :

```dart
import 'package:go_router/go_router.dart';
```

- [ ] **Step 2 : Remplacer `_StatusFilter` par `_Tab`**

Remplacer la ligne :
```dart
enum _StatusFilter { all, open, accepted }
```

Par :
```dart
enum _Tab { enCours, aVenir, passes }
```

- [ ] **Step 3 : Ajouter les fonctions utilitaires top-level juste avant `MyPackageRequestsScreen`**

```dart
List<PackageRequest> _filteredRequests(
    _Tab tab, List<PackageRequest> all) =>
    switch (tab) {
      _Tab.enCours => all
          .where((r) =>
              r.status == PackageRequestStatus.negotiating ||
              r.status == PackageRequestStatus.accepted)
          .toList(),
      _Tab.aVenir =>
          all.where((r) => r.status == PackageRequestStatus.open).toList(),
      _Tab.passes => all
          .where((r) =>
              r.status == PackageRequestStatus.completed ||
              r.status == PackageRequestStatus.expired ||
              r.status == PackageRequestStatus.cancelled)
          .toList(),
    };

({int enCours, int aVenir, int passes}) _tabCounts(
        List<PackageRequest> all) =>
    (
      enCours: all
          .where((r) =>
              r.status == PackageRequestStatus.negotiating ||
              r.status == PackageRequestStatus.accepted)
          .length,
      aVenir:
          all.where((r) => r.status == PackageRequestStatus.open).length,
      passes: all
          .where((r) =>
              r.status == PackageRequestStatus.completed ||
              r.status == PackageRequestStatus.expired ||
              r.status == PackageRequestStatus.cancelled)
          .length,
    );

// 0=Publié actif, 1=Accepté, 2=En route, 4=toutes done, -1=terminal grisé
int _activeStep(PackageRequestStatus status) => switch (status) {
      PackageRequestStatus.open => 0,
      PackageRequestStatus.negotiating => 1,
      PackageRequestStatus.accepted => 2,
      PackageRequestStatus.completed => 4,
      _ => -1,
    };

String _ctaLabel(PackageRequestStatus status) => switch (status) {
      PackageRequestStatus.open => 'Modifier →',
      PackageRequestStatus.negotiating ||
      PackageRequestStatus.accepted =>
        'Voir →',
      _ => 'Détail →',
    };

String _shortId(String id) =>
    '#${(id.length >= 8 ? id.substring(0, 8) : id).toUpperCase()}';
```

- [ ] **Step 4 : Mettre à jour `_buildDetails` pour retirer le prix (visible uniquement dans le détail)**

Remplacer la fonction `_buildDetails` en bas du fichier :

```dart
String _buildDetails(PackageRequest r) {
  final date = DateFormat('d MMM', 'fr').format(r.desiredDate);
  final parts = [
    '$date ±${r.dateToleranceDays}j',
    '${r.weightKg.toStringAsFixed(0)} kg',
    _shortCat(r.contentCategory.label),
  ];
  return parts.join(' · ');
}
```

- [ ] **Step 5 : Lancer `flutter analyze` pour contrôle intermédiaire**

```bash
flutter analyze lib/features/package_request/presentation/screens/sender/my_package_requests_screen.dart
```

Il y aura des erreurs de références aux widgets supprimés — c'est normal à ce stade.

---

## Task 3 — Widget `_ProgressStepper`

**Files:**
- Modify: `lib/features/package_request/presentation/screens/sender/my_package_requests_screen.dart`

- [ ] **Step 1 : Ajouter `_ProgressStepper` dans la section helpers, avant `_timeAgo`**

```dart
// ── Progress Stepper ──────────────────────────────────────────────────────────

class _ProgressStepper extends StatelessWidget {
  const _ProgressStepper({required this.status});
  final PackageRequestStatus status;

  static const _labels = ['Publié', 'Accepté', 'En route', 'Livré'];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final active = _activeStep(status);

    Color dotColor(int i) {
      if (active == 4) return cs.primary;
      if (active == -1) return cs.outlineVariant;
      if (i < active) return cs.primary;
      if (i == active) return cs.success;
      return cs.outlineVariant;
    }

    Color connectorColor(int i) {
      if (active == 4) return cs.primary;
      if (active == -1) return cs.outlineVariant;
      return i < active ? cs.primary : cs.outlineVariant;
    }

    bool isActive(int i) => active >= 0 && active < 4 && i == active;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < 4; i++) ...[
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: isActive(i) ? 11 : 9,
                height: isActive(i) ? 11 : 9,
                decoration: BoxDecoration(
                  color: dotColor(i),
                  shape: BoxShape.circle,
                  boxShadow: isActive(i)
                      ? [
                          BoxShadow(
                            color: dotColor(i).withValues(alpha: 0.3),
                            blurRadius: 6,
                            spreadRadius: 2,
                          ),
                        ]
                      : null,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                _labels[i],
                style: TextStyle(
                  fontSize: 7.5,
                  fontWeight:
                      isActive(i) ? FontWeight.w800 : FontWeight.w600,
                  color: isActive(i) ? dotColor(i) : cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
          if (i < 3)
            Expanded(
              child: Padding(
                // décalage vers le bas pour aligner sur le centre du dot
                padding: const EdgeInsets.only(bottom: 14),
                child: Container(
                  height: 2,
                  color: connectorColor(i),
                ),
              ),
            ),
        ],
      ],
    );
  }
}
```

- [ ] **Step 2 : Lancer les tests stepper (doivent encore échouer car pas intégré à la card)**

```bash
flutter test test/features/package_request/presentation/screens/sender/my_package_requests_screen_test.dart --name "4 labels"
```

Résultat attendu : FAIL — `_ProgressStepper` existe mais n'est pas encore rendu dans `_RequestCard`.

---

## Task 4 — Réécriture `_RequestCard` + `_CardAction`

**Files:**
- Modify: `lib/features/package_request/presentation/screens/sender/my_package_requests_screen.dart`

- [ ] **Step 1 : Supprimer `_accentColor` et réécrire `_RequestCard.build()`**

Supprimer la méthode `_accentColor` et remplacer tout le contenu de `_RequestCard.build()` :

```dart
@override
Widget build(BuildContext context) {
  final cs = Theme.of(context).colorScheme;
  final tt = Theme.of(context).textTheme;

  final statusColor = switch (request.status) {
    PackageRequestStatus.open => cs.primary,
    PackageRequestStatus.negotiating => cs.warning,
    PackageRequestStatus.accepted ||
    PackageRequestStatus.completed =>
      cs.success,
    _ => cs.onSurfaceVariant,
  };

  return Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(DonyRadius.card),
    child: InkWell(
      borderRadius: BorderRadius.circular(DonyRadius.card),
      onTap: () => PackageRequestDetailBottomSheet.show(context, request.id),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(DonyRadius.card),
          border: Border.all(color: DonyColors.neutral200),
        ),
        clipBehavior: Clip.antiAlias,
        padding: const EdgeInsets.all(DonySpacing.base),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ligne 1 : dot + badge statut + ref ID
            Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: DonySpacing.xs),
                _StatusBadge(status: request.status),
                const Spacer(),
                Text(
                  _shortId(request.id),
                  style: tt.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
            const SizedBox(height: DonySpacing.xs),
            // Ligne 2 : route
            Text(
              '${request.departureCity} → ${request.arrivalCity}',
              style: tt.titleLarge?.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: DonyColors.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: DonySpacing.sm + 2),
            // Ligne 3 : stepper
            _ProgressStepper(status: request.status),
            const SizedBox(height: DonySpacing.sm + 2),
            // Ligne 4 : méta chips (date, poids, catégorie)
            Text(
              _buildDetails(request),
              style: tt.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: DonySpacing.xs),
            // Ligne 5 : date livraison souhaitée + CTA
            Row(
              children: [
                Text(
                  '📅 ${DateFormat('d MMM yyyy', 'fr').format(request.desiredDate)}',
                  style: tt.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
                const Spacer(),
                _CardAction(request: request),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
```

- [ ] **Step 2 : Réécrire `_CardAction.build()`**

```dart
@override
Widget build(BuildContext context) {
  final cs = Theme.of(context).colorScheme;
  final tt = Theme.of(context).textTheme;
  final label = _ctaLabel(request.status);
  final isDisabled = request.status == PackageRequestStatus.expired ||
      request.status == PackageRequestStatus.cancelled;

  return GestureDetector(
    onTap: isDisabled
        ? null
        : () {
            if (request.status == PackageRequestStatus.open) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Modification à venir'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            } else {
              PackageRequestDetailBottomSheet.show(context, request.id);
            }
          },
    child: Text(
      label,
      style: tt.labelSmall?.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: isDisabled ? cs.onSurfaceVariant : cs.primary,
      ),
    ),
  );
}
```

- [ ] **Step 3 : Vérifier `flutter analyze`**

```bash
flutter analyze lib/features/package_request/presentation/screens/sender/my_package_requests_screen.dart
```

---

## Task 5 — Widgets `_DarkHeader` + `_DarkTab`

**Files:**
- Modify: `lib/features/package_request/presentation/screens/sender/my_package_requests_screen.dart`

- [ ] **Step 1 : Supprimer les widgets obsolètes `_FilterRow`, `_FilterChip`, `_FilterEmptyState`**

Retirer entièrement les trois classes `_FilterRow`, `_FilterChip`, et `_FilterEmptyState` du fichier.

- [ ] **Step 2 : Ajouter `_DarkHeader` et `_DarkTab` à la place (section "── Dark Header ──")**

```dart
// ── Dark Header ───────────────────────────────────────────────────────────────

class _DarkHeader extends StatelessWidget {
  const _DarkHeader({
    required this.activeTab,
    required this.counts,
    required this.onTabChanged,
  });

  final _Tab activeTab;
  final ({int enCours, int aVenir, int passes}) counts;
  final ValueChanged<_Tab> onTabChanged;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final canGoBack = context.canPop();

    final activeCount = switch (activeTab) {
      _Tab.enCours => counts.enCours,
      _Tab.aVenir => counts.aVenir,
      _Tab.passes => counts.passes,
    };

    return Container(
      color: const Color(0xFF0A2540),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: MediaQuery.of(context).padding.top),
          // Ligne titre
          Padding(
            padding: const EdgeInsets.fromLTRB(
                DonySpacing.xs, DonySpacing.sm, DonySpacing.base, DonySpacing.xs),
            child: Row(
              children: [
                if (canGoBack)
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(DonyRadius.iconBtn),
                      ),
                      child: const Icon(
                        Icons.chevron_left_rounded,
                        size: 20,
                        color: Colors.white,
                      ),
                    ),
                    onPressed: () => context.pop(),
                  )
                else
                  const SizedBox(width: DonySpacing.base),
                const SizedBox(width: DonySpacing.xs),
                Expanded(
                  child: Text(
                    'Mes envois',
                    style: tt.titleLarge?.copyWith(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (activeCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: DonySpacing.sm,
                        vertical: DonySpacing.xxs + 1),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(DonyRadius.full),
                    ),
                    child: Text(
                      '$activeCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Ligne tabs
          Padding(
            padding: const EdgeInsets.fromLTRB(
                DonySpacing.base, 0, DonySpacing.base, DonySpacing.sm),
            child: Row(
              children: [
                _DarkTab(
                  label: 'En cours',
                  active: activeTab == _Tab.enCours,
                  onTap: () => onTabChanged(_Tab.enCours),
                ),
                const SizedBox(width: DonySpacing.xs),
                _DarkTab(
                  label: 'À venir',
                  active: activeTab == _Tab.aVenir,
                  onTap: () => onTabChanged(_Tab.aVenir),
                ),
                const SizedBox(width: DonySpacing.xs),
                _DarkTab(
                  label: 'Passés',
                  active: activeTab == _Tab.passes,
                  onTap: () => onTabChanged(_Tab.passes),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DarkTab extends StatelessWidget {
  const _DarkTab({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(
            horizontal: DonySpacing.md, vertical: DonySpacing.xs + 2),
        decoration: BoxDecoration(
          color: active ? Colors.white.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(DonyRadius.sm),
          border: active
              ? Border.all(
                  color: Colors.white.withValues(alpha: 0.4), width: 1)
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : Colors.white.withValues(alpha: 0.5),
            fontSize: 12,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
```

---

## Task 6 — Réécriture de `MyPackageRequestsScreen` + `_ListContentState`

**Files:**
- Modify: `lib/features/package_request/presentation/screens/sender/my_package_requests_screen.dart`

- [ ] **Step 1 : Mettre à jour `MyPackageRequestsScreen.build()`**

Remplacer entièrement la méthode `build` de `MyPackageRequestsScreen` :

```dart
@override
Widget build(BuildContext context) {
  return const Scaffold(
    backgroundColor: Color(0xFFF2F1EF),
    body: MyPackageRequestsBody(showFab: true),
  );
}
```

- [ ] **Step 2 : Remplacer `_filter` par `_tab` dans `_ListContentState`**

Dans `_ListContentState`, changer :
```dart
_StatusFilter _filter = _StatusFilter.all;
```
par :
```dart
_Tab _tab = _Tab.enCours;
```

- [ ] **Step 3 : Supprimer la méthode `_applyFilter` de `_ListContentState`**

La logique de filtrage est maintenant dans la fonction top-level `_filteredRequests`.

- [ ] **Step 4 : Réécrire `_ListContentState.build()`**

```dart
@override
Widget build(BuildContext context) {
  return BlocBuilder<PackageRequestBloc, PackageRequestState>(
    builder: (context, state) {
      final counts = state.status == PackageRequestListStatus.loaded
          ? _tabCounts(state.requests)
          : (enCours: 0, aVenir: 0, passes: 0);

      final header = _DarkHeader(
        activeTab: _tab,
        counts: counts,
        onTabChanged: (t) => setState(() => _tab = t),
      );

      Widget body;
      if (state.status == PackageRequestListStatus.loading) {
        body = Center(
          child: CircularProgressIndicator(
              color: Theme.of(context).colorScheme.primary),
        );
      } else if (state.status == PackageRequestListStatus.error) {
        body = _ErrorView(
          message: state.errorMessage ?? 'Erreur',
          onRetry: () =>
              context.read<PackageRequestBloc>().add(const FetchMyRequests()),
        );
      } else {
        final filtered = _filteredRequests(_tab, state.requests);
        body = filtered.isEmpty
            ? _buildTabEmptyState(context)
            : RefreshIndicator(
                color: Theme.of(context).colorScheme.primary,
                onRefresh: () async {
                  context
                      .read<PackageRequestBloc>()
                      .add(const RefreshMyRequests());
                },
                child: ListView.separated(
                  padding: EdgeInsets.fromLTRB(
                    DonySpacing.lg,
                    DonySpacing.base,
                    DonySpacing.lg,
                    MediaQuery.of(context).padding.bottom + 100,
                  ),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: DonySpacing.sm),
                  itemBuilder: (context, i) {
                    return _RequestCard(request: filtered[i])
                        .animate()
                        .fadeIn(duration: 200.ms, delay: (50 * i).ms)
                        .slideY(begin: 0.03, curve: Curves.easeOutCubic);
                  },
                ),
              );
      }

      final content = Column(
        children: [
          header,
          Expanded(child: body),
        ],
      );

      if (!widget.showFab) return content;

      return Stack(
        children: [
          Positioned.fill(child: content),
          Positioned(
            right: DonySpacing.lg,
            bottom: DonySpacing.xl,
            child: FloatingActionButton.extended(
              heroTag: 'my-package-requests-fab',
              onPressed: () async {
                await PackageRequestCreateWizard.show(context);
                if (context.mounted) {
                  context
                      .read<PackageRequestBloc>()
                      .add(const RefreshMyRequests());
                }
              },
              backgroundColor: Theme.of(context).colorScheme.primary,
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: Text(
                'Nouvelle demande',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium!
                    .copyWith(
                        fontWeight: FontWeight.w600, color: Colors.white),
              ),
            ),
          ),
        ],
      );
    },
  );
}

Widget _buildTabEmptyState(BuildContext context) {
  return switch (_tab) {
    _Tab.enCours => DonyEmptyState(
        title: 'Aucun envoi en cours',
        description:
            'Tes envois en négociation ou acceptés apparaîtront ici.',
        mascotte: DonyMascotteType.assis,
        actionLabel: '+ Publier une demande',
        onAction: () async {
          await PackageRequestCreateWizard.show(context);
          if (context.mounted) {
            context
                .read<PackageRequestBloc>()
                .add(const RefreshMyRequests());
          }
        },
      ),
    _Tab.aVenir => const DonyEmptyState(
        title: 'Aucune demande ouverte',
        description:
            'Tes demandes en attente de voyageur apparaîtront ici.',
        mascotte: DonyMascotteType.assis,
      ),
    _Tab.passes => const DonyEmptyState(
        title: 'Aucun historique',
        description:
            'Tes envois complétés, expirés et annulés apparaîtront ici.',
        mascotte: DonyMascotteType.assis,
      ),
  };
}
```

---

## Task 7 — Lancer les tests, corriger et valider

**Files:**
- Modify: `lib/features/package_request/presentation/screens/sender/my_package_requests_screen.dart`
- Modify: `test/features/package_request/presentation/screens/sender/my_package_requests_screen_test.dart`

- [ ] **Step 1 : `flutter analyze` complet**

```bash
cd /home/a-diakite/Desktop/MyProject/my_app/dony_app
flutter analyze lib/features/package_request/presentation/screens/sender/my_package_requests_screen.dart
```

Résultat attendu : 0 erreurs, 0 warnings.

- [ ] **Step 2 : Lancer tous les tests de l'écran**

```bash
flutter test test/features/package_request/presentation/screens/sender/my_package_requests_screen_test.dart --reporter expanded
```

Résultat attendu : tous les tests passent. Référence complète :
- `affiche CircularProgressIndicator en état loading` ✓
- `affiche empty state "Aucun envoi en cours" quand la liste est vide` ✓
- `affiche le texte d'erreur quand status = error` ✓
- `affiche les cards quand des demandes existent` ✓ (route "Paris → Dakar" visible)
- `affiche les trois onglets dans le header` ✓
- `tab "En cours" affiche negotiating et accepted, pas open` ✓
- `tab "À venir" affiche open uniquement` ✓
- `tab "Passés" affiche completed et expired, pas open` ✓
- `card affiche les 4 labels du stepper` ✓
- `CTA "Modifier →" pour status=open` ✓
- `CTA "Voir →" pour status=negotiating` ✓
- `CTA "Voir →" pour status=accepted` ✓
- `CTA "Détail →" pour status=completed` ✓
- `badge OUVERTE pour status=open` ✓ (après tap "À venir")
- `badge NÉGOCIATION pour status=negotiating` ✓
- `badge ACCEPTÉE pour status=accepted` ✓
- `badge EXPIRÉE pour status=expired` ✓ (après tap "Passés")
- `tab "En cours" vide → "Aucun envoi en cours"` ✓
- `tab "À venir" vide → "Aucune demande ouverte"` ✓
- `tab "Passés" vide → "Aucun historique"` ✓

- [ ] **Step 3 : Lancer la couverture globale**

```bash
flutter test --coverage
```

Résultat attendu : couverture globale ≥ 90 %.

- [ ] **Step 4 : Commit final**

```bash
git add lib/features/package_request/presentation/screens/sender/my_package_requests_screen.dart
git add test/features/package_request/presentation/screens/sender/my_package_requests_screen_test.dart
git commit -m "feat(mes-envois): redesign — header #0A2540, tabs En cours/À venir/Passés, stepper 4 étapes"
```

---

## Vérification visuelle post-implémentation

```bash
# Lancer l'app sur émulateur
flutter run --dart-define-from-file=env.dev.json

# Parcours de validation :
# 1. Naviguer vers "Mes envois" depuis le profil expéditeur
# 2. Header sombre #0A2540 visible, titre "Mes envois", 3 tabs
# 3. Tab "En cours" active par défaut
# 4. Si aucune demande negotiating/accepted : "Aucun envoi en cours" + mascotte assis
# 5. Switcher sur "À venir" : demandes open visibles
#    → Chaque card : badge OUVERTE, route en gras, stepper (dot vert sur "Publié"), CTA "Modifier →"
# 6. Switcher sur "Passés" : demandes expired/completed
#    → Stepper grisé (expired) ou tout bleu (completed)
# 7. Switcher sur "En cours" avec demandes negotiating/accepted :
#    → NÉGOCIATION : dot vert sur "Accepté", CTA "Voir →"
#    → ACCEPTÉE : dot vert sur "En route", CTA "Voir →"
# 8. Badge compteur dans le header change selon la tab active
```
