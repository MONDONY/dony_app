# Bottom sheet « Trajet lié » + refus de trajet — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Permettre à l'expéditeur, dans l'écran de négociation au statut « À RÉGLER », de consulter le détail du trajet lié dans un bottom sheet et de le refuser avec une raison ; côté voyageur, voir cette raison et proposer un autre trajet.

**Architecture:** Feature 100 % Flutter (le backend expose déjà `linkedTrip` et `POST /negotiations/{id}/refuse-trip`). On ajoute un modèle `LinkedTripSummary`, une méthode repo `refuseTrip`, un event BLoC `NegotiationRefuseTripRequested`, deux bottom sheets (`TripDetailBottomSheet` timeline + `RefuseTripBottomSheet` raison), on rend le hero card cliquable et on affiche le message de refus comme bandeau distinct côté voyageur.

**Tech Stack:** Flutter, flutter_bloc, equatable, mocktail, bloc_test, Dio. Branche `refactor/details-trajet` du projet `dony_app`.

**Spec de référence :** `docs/superpowers/specs/2026-05-16-trajet-lie-bottom-sheet-design.md`

**Conventions du projet :**
- Tous les commits sur la branche `refactor/details-trajet` (pas de commit sur `main`).
- Messages de commit en convention `type(scope): description` (français), terminés par le trailer Co-Authored-By montré dans chaque step.
- Lancer les tests avec `flutter test`. Un test isolé : `flutter test <chemin> --plain-name "<extrait du nom>"`.
- Règle projet : `DonyButton` dans un bottom sheet **toujours** dans `stickyBottom`, jamais dans le `child`.

---

## File Structure

**Créés :**
- `lib/features/package_request/data/models/linked_trip_summary.dart` — modèle du trajet lié.
- `lib/features/package_request/presentation/widgets/thread/refuse_trip_bottom_sheet.dart` — sheet de saisie de la raison du refus.
- `lib/features/package_request/presentation/widgets/thread/trip_detail_bottom_sheet.dart` — sheet timeline du trajet lié.
- `test/features/package_request/data/models/linked_trip_summary_test.dart`
- `test/features/package_request/presentation/widgets/thread/refuse_trip_bottom_sheet_test.dart`
- `test/features/package_request/presentation/widgets/thread/trip_detail_bottom_sheet_test.dart`

**Modifiés :**
- `lib/features/package_request/data/models/negotiation_thread.dart` — champ `linkedTrip`.
- `lib/features/package_request/data/negotiation_repository.dart` — méthode `refuseTrip`.
- `lib/features/package_request/bloc/negotiation_bloc.dart` — event + handler.
- `lib/features/package_request/presentation/widgets/thread/thread_hero_card.dart` — paramètre `onTap` + affordance.
- `lib/features/package_request/presentation/widgets/thread/thread_message_bubble.dart` — paramètre `isTripRefusal` + bandeau.
- `lib/features/package_request/presentation/screens/shared/negotiation_thread_screen.dart` — câblage `onTap` + flag `isTripRefusal`.
- Tests correspondants : `negotiation_thread_test.dart`, `negotiation_repository_test.dart`, `negotiation_bloc_test.dart`, `thread_hero_card_test.dart`, `thread_message_bubble_test.dart`, `negotiation_thread_screen_test.dart`.

---

## Task 1: Modèle `LinkedTripSummary`

**Files:**
- Create: `lib/features/package_request/data/models/linked_trip_summary.dart`
- Test: `test/features/package_request/data/models/linked_trip_summary_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/features/package_request/data/models/linked_trip_summary_test.dart` :

```dart
import 'package:dony/features/package_request/data/models/linked_trip_summary.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LinkedTripSummary.fromJson', () {
    test('parse tous les champs présents', () {
      final t = LinkedTripSummary.fromJson(const {
        'announcementId': 'ann-1',
        'departureCity': 'Paris',
        'arrivalCity': 'Dakar',
        'departureDate': '2026-06-12',
        'departureTime': '14:30',
        'transportMode': 'PLANE',
        'pickupAddressLabel': 'Gare de Lyon, Paris',
        'deliveryAddressLabel': 'Plateau, Dakar',
        'availableKg': 18,
        'description': 'Remise possible la veille.',
      });

      expect(t.announcementId, 'ann-1');
      expect(t.departureCity, 'Paris');
      expect(t.arrivalCity, 'Dakar');
      expect(t.departureDate, '2026-06-12');
      expect(t.departureTime, '14:30');
      expect(t.transportMode, 'PLANE');
      expect(t.pickupAddressLabel, 'Gare de Lyon, Paris');
      expect(t.deliveryAddressLabel, 'Plateau, Dakar');
      expect(t.availableKg, 18);
      expect(t.description, 'Remise possible la veille.');
    });

    test('retourne null pour les champs optionnels absents', () {
      final t = LinkedTripSummary.fromJson(const {'announcementId': 'ann-2'});

      expect(t.announcementId, 'ann-2');
      expect(t.departureCity, isNull);
      expect(t.arrivalCity, isNull);
      expect(t.departureDate, isNull);
      expect(t.departureTime, isNull);
      expect(t.transportMode, isNull);
      expect(t.pickupAddressLabel, isNull);
      expect(t.deliveryAddressLabel, isNull);
      expect(t.availableKg, isNull);
      expect(t.description, isNull);
    });

    test('availableKg accepte un num et le convertit en int', () {
      final t = LinkedTripSummary.fromJson(const {
        'announcementId': 'ann-3',
        'availableKg': 20.0,
      });
      expect(t.availableKg, 20);
    });

    test('deux instances aux mêmes valeurs sont égales (Equatable)', () {
      const json = {'announcementId': 'ann-4', 'departureCity': 'Lyon'};
      expect(LinkedTripSummary.fromJson(json),
          LinkedTripSummary.fromJson(json));
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/package_request/data/models/linked_trip_summary_test.dart`
Expected: FAIL — `Error: Couldn't resolve the package 'linked_trip_summary.dart'` / `LinkedTripSummary` introuvable.

- [ ] **Step 3: Write the model**

Create `lib/features/package_request/data/models/linked_trip_summary.dart` :

```dart
import 'package:equatable/equatable.dart';

/// Détails du trajet lié à une négociation.
///
/// Mappé sur le record backend `LinkedTripSummary` exposé dans
/// `NegotiationThreadResponse.linkedTrip`. Tous les champs sont optionnels
/// sauf [announcementId] — le backend peut ne pas tous les renseigner.
class LinkedTripSummary extends Equatable {
  const LinkedTripSummary({
    required this.announcementId,
    this.departureCity,
    this.arrivalCity,
    this.departureDate,
    this.departureTime,
    this.transportMode,
    this.pickupAddressLabel,
    this.deliveryAddressLabel,
    this.availableKg,
    this.description,
  });

  final String announcementId;
  final String? departureCity;
  final String? arrivalCity;

  /// Date ISO `"2026-06-12"`.
  final String? departureDate;

  /// Heure `"14:30"`.
  final String? departureTime;

  /// `"PLANE"` | `"TRAIN"` | `"CAR"`.
  final String? transportMode;

  final String? pickupAddressLabel;
  final String? deliveryAddressLabel;
  final int? availableKg;
  final String? description;

  factory LinkedTripSummary.fromJson(Map<String, dynamic> json) =>
      LinkedTripSummary(
        announcementId: json['announcementId'] as String,
        departureCity: json['departureCity'] as String?,
        arrivalCity: json['arrivalCity'] as String?,
        departureDate: json['departureDate'] as String?,
        departureTime: json['departureTime'] as String?,
        transportMode: json['transportMode'] as String?,
        pickupAddressLabel: json['pickupAddressLabel'] as String?,
        deliveryAddressLabel: json['deliveryAddressLabel'] as String?,
        availableKg: (json['availableKg'] as num?)?.toInt(),
        description: json['description'] as String?,
      );

  @override
  List<Object?> get props => [
        announcementId,
        departureCity,
        arrivalCity,
        departureDate,
        departureTime,
        transportMode,
        pickupAddressLabel,
        deliveryAddressLabel,
        availableKg,
        description,
      ];
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/package_request/data/models/linked_trip_summary_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/package_request/data/models/linked_trip_summary.dart \
        test/features/package_request/data/models/linked_trip_summary_test.dart
git commit -m "$(cat <<'EOF'
feat(negotiation): modèle LinkedTripSummary

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: Champ `linkedTrip` sur `NegotiationThread`

**Files:**
- Modify: `lib/features/package_request/data/models/negotiation_thread.dart`
- Test: `test/features/package_request/data/models/negotiation_thread_test.dart`

- [ ] **Step 1: Write the failing test**

Dans `test/features/package_request/data/models/negotiation_thread_test.dart`, ajouter ces deux tests à l'intérieur de `void main() { ... }`, après le test `'... retourne null pour les champs absents'` :

```dart
  test('NegotiationThread.fromJson parse linkedTrip quand présent', () {
    final t = NegotiationThread.fromJson(_baseJson(overrides: {
      'linkedTrip': {
        'announcementId': 'ann-1',
        'departureCity': 'Paris',
        'arrivalCity': 'Dakar',
        'departureDate': '2026-06-12',
        'transportMode': 'PLANE',
        'availableKg': 18,
      },
    }));

    expect(t.linkedTrip, isNotNull);
    expect(t.linkedTrip!.announcementId, 'ann-1');
    expect(t.linkedTrip!.departureCity, 'Paris');
    expect(t.linkedTrip!.transportMode, 'PLANE');
  });

  test('NegotiationThread.fromJson retourne linkedTrip null si absent', () {
    final t = NegotiationThread.fromJson(_baseJson());
    expect(t.linkedTrip, isNull);
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/package_request/data/models/negotiation_thread_test.dart --plain-name "linkedTrip"`
Expected: FAIL — `The getter 'linkedTrip' isn't defined for the class 'NegotiationThread'`.

- [ ] **Step 3: Add the field**

Dans `lib/features/package_request/data/models/negotiation_thread.dart` :

a. Ajouter l'import en haut, après l'import de `negotiation_message.dart` :

```dart
import 'package:dony/features/package_request/data/models/linked_trip_summary.dart';
```

b. Dans le constructeur `const NegotiationThread({ ... })`, ajouter après `this.weightKg,` :

```dart
    this.linkedTrip,
```

c. Après la déclaration du champ `final double? weightKg;`, ajouter :

```dart

  /// Détails du trajet lié — non null uniquement quand le voyageur a lié un
  /// trajet (statuts AWAITING_PAYMENT / ACCEPTED).
  final LinkedTripSummary? linkedTrip;
```

d. Dans `factory NegotiationThread.fromJson`, ajouter après la ligne `weightKg: (json['weightKg'] as num?)?.toDouble(),` :

```dart
        linkedTrip: json['linkedTrip'] == null
            ? null
            : LinkedTripSummary.fromJson(
                json['linkedTrip'] as Map<String, dynamic>),
```

e. Dans `List<Object?> get props`, ajouter `linkedTrip` à la fin de la liste (après `weightKg,`).

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/package_request/data/models/negotiation_thread_test.dart`
Expected: PASS (tous les tests du fichier, dont les 2 nouveaux).

- [ ] **Step 5: Commit**

```bash
git add lib/features/package_request/data/models/negotiation_thread.dart \
        test/features/package_request/data/models/negotiation_thread_test.dart
git commit -m "$(cat <<'EOF'
feat(negotiation): champ linkedTrip sur NegotiationThread

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Méthode repository `refuseTrip`

**Files:**
- Modify: `lib/features/package_request/data/negotiation_repository.dart`
- Test: `test/features/package_request/data/negotiation_repository_test.dart`

- [ ] **Step 1: Write the failing test**

Dans `test/features/package_request/data/negotiation_repository_test.dart`, ajouter ce groupe à l'intérieur de `void main() { ... }`, après le groupe `group('reject', () { ... });` :

```dart
  group('refuseTrip', () {
    test('POSTs to /negotiations/:id/refuse-trip avec la raison', () async {
      when(
        () => mockDio.post<Map<String, dynamic>>(
          '/negotiations/th-1/refuse-trip',
          data: any(named: 'data'),
        ),
      ).thenAnswer((_) async => _ok(_threadJson, '/negotiations/th-1/refuse-trip'));

      final thread = await repo.refuseTrip('th-1', reason: 'Date trop tard');

      expect(thread.id, 'th-1');
      verify(
        () => mockDio.post<Map<String, dynamic>>(
          '/negotiations/th-1/refuse-trip',
          data: {'reason': 'Date trop tard'},
        ),
      ).called(1);
    });

    test('POSTs sans data quand reason est null', () async {
      when(
        () => mockDio.post<Map<String, dynamic>>(
          '/negotiations/th-1/refuse-trip',
          data: any(named: 'data'),
        ),
      ).thenAnswer((_) async => _ok(_threadJson, '/negotiations/th-1/refuse-trip'));

      await repo.refuseTrip('th-1');

      verify(
        () => mockDio.post<Map<String, dynamic>>(
          '/negotiations/th-1/refuse-trip',
          data: <String, dynamic>{},
        ),
      ).called(1);
    });
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/package_request/data/negotiation_repository_test.dart --plain-name "refuseTrip"`
Expected: FAIL — `The method 'refuseTrip' isn't defined for the class 'NegotiationRepository'`.

- [ ] **Step 3: Add the method**

Dans `lib/features/package_request/data/negotiation_repository.dart`, ajouter cette méthode juste après la méthode `submitTrip` :

```dart
  /// Sender refuses the trip the traveler linked to an AWAITING_PAYMENT thread.
  /// The backend clears the linked trip, moves the thread back to AWAITING_TRIP
  /// and records [reason] as a REJECT message visible to the traveler.
  Future<NegotiationThread> refuseTrip(String id, {String? reason}) async {
    final response = await _apiClient.dio.post<Map<String, dynamic>>(
      '/negotiations/$id/refuse-trip',
      data: {if (reason != null) 'reason': reason},
    );
    return NegotiationThread.fromJson(response.data!);
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/package_request/data/negotiation_repository_test.dart`
Expected: PASS (tous les tests du fichier).

- [ ] **Step 5: Commit**

```bash
git add lib/features/package_request/data/negotiation_repository.dart \
        test/features/package_request/data/negotiation_repository_test.dart
git commit -m "$(cat <<'EOF'
feat(negotiation): repository.refuseTrip

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: Event + handler BLoC `NegotiationRefuseTripRequested`

**Files:**
- Modify: `lib/features/package_request/bloc/negotiation_bloc.dart`
- Test: `test/features/package_request/bloc/negotiation_bloc_test.dart`

- [ ] **Step 1: Write the failing test**

Dans `test/features/package_request/bloc/negotiation_bloc_test.dart`, ajouter ces deux `blocTest` à l'intérieur de `void main() { ... }`, à la fin (avant la dernière `}`):

```dart
  blocTest<NegotiationBloc, NegotiationState>(
    'refuseTrip depuis Loaded émet ActionInProgress puis Loaded',
    build: () {
      when(() => repo.refuseTrip(any(), reason: any(named: 'reason')))
          .thenAnswer((_) async =>
              _fakeThread(status: NegotiationThreadStatus.awaitingTrip));
      return NegotiationBloc(repo);
    },
    seed: () => NegotiationLoaded(_fakeThread(
        status: NegotiationThreadStatus.awaitingPayment)),
    act: (bloc) => bloc.add(const NegotiationRefuseTripRequested(
      threadId: 't-1',
      reason: 'Date trop tard',
    )),
    expect: () => [
      isA<NegotiationActionInProgress>(),
      isA<NegotiationLoaded>().having(
        (s) => s.thread.status,
        'thread.status',
        NegotiationThreadStatus.awaitingTrip,
      ),
    ],
    verify: (_) {
      verify(() => repo.refuseTrip('t-1', reason: 'Date trop tard')).called(1);
    },
  );

  blocTest<NegotiationBloc, NegotiationState>(
    'refuseTrip émet Error quand le repository échoue',
    build: () {
      when(() => repo.refuseTrip(any(), reason: any(named: 'reason')))
          .thenThrow(Exception('boom'));
      return NegotiationBloc(repo);
    },
    seed: () => NegotiationLoaded(_fakeThread(
        status: NegotiationThreadStatus.awaitingPayment)),
    act: (bloc) => bloc.add(const NegotiationRefuseTripRequested(
      threadId: 't-1',
      reason: 'x',
    )),
    expect: () => [
      isA<NegotiationActionInProgress>(),
      isA<NegotiationError>(),
    ],
  );
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/package_request/bloc/negotiation_bloc_test.dart --plain-name "refuseTrip"`
Expected: FAIL — `NegotiationRefuseTripRequested` introuvable.

- [ ] **Step 3: Add the event**

Dans `lib/features/package_request/bloc/negotiation_bloc.dart`, ajouter cette classe d'event juste après la classe `NegotiationCreateDedicatedTripRequested` (avant `sealed class NegotiationState`) :

```dart
/// Sender refuses the trip linked to an AWAITING_PAYMENT thread, with a reason.
class NegotiationRefuseTripRequested extends NegotiationEvent {
  const NegotiationRefuseTripRequested({
    required this.threadId,
    this.reason,
  });
  final String threadId;
  final String? reason;

  @override
  List<Object?> get props => [threadId, reason];
}
```

- [ ] **Step 4: Register the handler and implement it**

Dans le constructeur `NegotiationBloc`, ajouter après `on<NegotiationCreateDedicatedTripRequested>(_onCreateDedicatedTrip);` :

```dart
    on<NegotiationRefuseTripRequested>(_onRefuseTrip);
```

Ajouter le handler juste après la méthode `_onSubmitTrip` :

```dart
  Future<void> _onRefuseTrip(
    NegotiationRefuseTripRequested e,
    Emitter<NegotiationState> emit,
  ) async {
    final current = state;
    if (current is NegotiationLoaded) {
      emit(NegotiationActionInProgress(current.thread));
    } else {
      emit(const NegotiationLoading());
    }
    try {
      final thread =
          await _repository.refuseTrip(e.threadId, reason: e.reason);
      emit(NegotiationLoaded(thread));
    } catch (err) {
      emit(NegotiationError(unwrapDioError(err)));
    }
  }
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/features/package_request/bloc/negotiation_bloc_test.dart`
Expected: PASS (tous les tests du fichier).

- [ ] **Step 6: Commit**

```bash
git add lib/features/package_request/bloc/negotiation_bloc.dart \
        test/features/package_request/bloc/negotiation_bloc_test.dart
git commit -m "$(cat <<'EOF'
feat(negotiation): event BLoC NegotiationRefuseTripRequested

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: `RefuseTripBottomSheet`

Sheet de saisie de la raison du refus. Raison obligatoire : bouton désactivé tant que le champ est vide (pattern CLAUDE.md « Bouton dépend d'état + BLoC »).

**Files:**
- Create: `lib/features/package_request/presentation/widgets/thread/refuse_trip_bottom_sheet.dart`
- Test: `test/features/package_request/presentation/widgets/thread/refuse_trip_bottom_sheet_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/features/package_request/presentation/widgets/thread/refuse_trip_bottom_sheet_test.dart` :

```dart
import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/design/widgets/dony_button.dart';
import 'package:dony/features/package_request/bloc/negotiation_bloc.dart';
import 'package:dony/features/package_request/presentation/widgets/thread/refuse_trip_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockNegotiationBloc
    extends MockBloc<NegotiationEvent, NegotiationState>
    implements NegotiationBloc {}

void main() {
  late _MockNegotiationBloc bloc;

  setUpAll(() {
    registerFallbackValue(
      const NegotiationRefuseTripRequested(threadId: 't-1'),
    );
  });

  setUp(() {
    bloc = _MockNegotiationBloc();
    when(() => bloc.state).thenReturn(const NegotiationInitial());
    when(() => bloc.stream)
        .thenAnswer((_) => const Stream<NegotiationState>.empty());
  });

  Future<void> openSheet(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: BlocProvider<NegotiationBloc>.value(
        value: bloc,
        child: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => RefuseTripBottomSheet.show(
              context,
              bloc: bloc,
              threadId: 't-1',
            ),
            child: const Text('Ouvrir'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();
  }

  group('RefuseTripBottomSheet', () {
    testWidgets('affiche le titre "Refuser ce trajet"', (tester) async {
      await openSheet(tester);
      expect(find.text('Refuser ce trajet'), findsOneWidget);
    });

    testWidgets('bouton désactivé tant que la raison est vide',
        (tester) async {
      await openSheet(tester);
      final btn = tester.widget<DonyButton>(find.byType(DonyButton));
      expect(btn.onPressed, isNull);
    });

    testWidgets('bouton activé une fois la raison saisie', (tester) async {
      await openSheet(tester);
      await tester.enterText(find.byType(TextField), 'Date trop tardive');
      await tester.pumpAndSettle();
      final btn = tester.widget<DonyButton>(find.byType(DonyButton));
      expect(btn.onPressed, isNotNull);
    });

    testWidgets('confirmer dispatch NegotiationRefuseTripRequested',
        (tester) async {
      await openSheet(tester);
      await tester.enterText(find.byType(TextField), 'Date trop tardive');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmer le refus'));
      await tester.pumpAndSettle();

      verify(() => bloc.add(const NegotiationRefuseTripRequested(
            threadId: 't-1',
            reason: 'Date trop tardive',
          ))).called(1);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/package_request/presentation/widgets/thread/refuse_trip_bottom_sheet_test.dart`
Expected: FAIL — `refuse_trip_bottom_sheet.dart` introuvable.

- [ ] **Step 3: Write the widget**

Create `lib/features/package_request/presentation/widgets/thread/refuse_trip_bottom_sheet.dart` :

```dart
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/design/widgets/dony_bottom_sheet.dart';
import 'package:dony/core/design/widgets/dony_button.dart';
import 'package:dony/features/package_request/bloc/negotiation_bloc.dart';
import 'package:dony/features/package_request/presentation/_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Bottom sheet de saisie de la raison du refus d'un trajet lié.
///
/// La raison est obligatoire : le bouton « Confirmer le refus » reste
/// désactivé tant que le champ est vide.
class RefuseTripBottomSheet {
  const RefuseTripBottomSheet._();

  static Future<void> show(
    BuildContext context, {
    required NegotiationBloc bloc,
    required String threadId,
  }) {
    final canSubmit = ValueNotifier<bool>(false);
    VoidCallback? submitFn;

    return DonyBottomSheet.show<void>(
      context,
      title: 'Refuser ce trajet',
      isDanger: true,
      wrapper: (child) => BlocProvider.value(value: bloc, child: child),
      child: _RefuseTripContent(
        bloc: bloc,
        threadId: threadId,
        canSubmit: canSubmit,
        onSubmitReady: (fn) => submitFn = fn,
      ),
      stickyBottom: ValueListenableBuilder<bool>(
        valueListenable: canSubmit,
        builder: (ctx, enabled, _) {
          return BlocBuilder<NegotiationBloc, NegotiationState>(
            bloc: bloc,
            builder: (ctx, state) {
              final loading = state is NegotiationActionInProgress ||
                  state is NegotiationLoading;
              return DonyButton(
                label: loading ? 'Envoi…' : 'Confirmer le refus',
                variant: DonyButtonVariant.destructive,
                isLoading: loading,
                onPressed:
                    (!enabled || loading) ? null : () => submitFn?.call(),
              );
            },
          );
        },
      ),
    ).whenComplete(canSubmit.dispose);
  }
}

class _RefuseTripContent extends StatefulWidget {
  const _RefuseTripContent({
    required this.bloc,
    required this.threadId,
    required this.canSubmit,
    required this.onSubmitReady,
  });
  final NegotiationBloc bloc;
  final String threadId;
  final ValueNotifier<bool> canSubmit;
  final void Function(VoidCallback) onSubmitReady;

  @override
  State<_RefuseTripContent> createState() => _RefuseTripContentState();
}

class _RefuseTripContentState extends State<_RefuseTripContent> {
  final _reasonCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.onSubmitReady(_submit);
    _reasonCtrl.addListener(_onChanged);
  }

  void _onChanged() {
    widget.canSubmit.value = _reasonCtrl.text.trim().isNotEmpty;
  }

  @override
  void dispose() {
    _reasonCtrl.removeListener(_onChanged);
    _reasonCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final reason = _reasonCtrl.text.trim();
    if (reason.isEmpty) return;
    widget.bloc.add(NegotiationRefuseTripRequested(
      threadId: widget.threadId,
      reason: reason,
    ));
    Navigator.of(context, rootNavigator: true).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Explique au voyageur pourquoi ce trajet ne convient pas. '
          'Il pourra ensuite en proposer un autre.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: kTextSecondary,
                height: 1.4,
              ),
        ),
        const SizedBox(height: DonySpacing.base),
        TextField(
          controller: _reasonCtrl,
          maxLines: 3,
          maxLength: 280,
          decoration: const InputDecoration(
            labelText: 'Raison du refus',
            hintText: 'Ex. la date est trop tardive pour mon colis…',
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/package_request/presentation/widgets/thread/refuse_trip_bottom_sheet_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/package_request/presentation/widgets/thread/refuse_trip_bottom_sheet.dart \
        test/features/package_request/presentation/widgets/thread/refuse_trip_bottom_sheet_test.dart
git commit -m "$(cat <<'EOF'
feat(negotiation): RefuseTripBottomSheet — saisie de la raison du refus

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: `TripDetailBottomSheet`

Sheet timeline du trajet lié. Côté expéditeur, bouton destructif « Refuser le trajet » qui ferme ce sheet et ouvre `RefuseTripBottomSheet`.

**Files:**
- Create: `lib/features/package_request/presentation/widgets/thread/trip_detail_bottom_sheet.dart`
- Test: `test/features/package_request/presentation/widgets/thread/trip_detail_bottom_sheet_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/features/package_request/presentation/widgets/thread/trip_detail_bottom_sheet_test.dart` :

```dart
import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/package_request/bloc/negotiation_bloc.dart';
import 'package:dony/features/package_request/data/models/linked_trip_summary.dart';
import 'package:dony/features/package_request/presentation/widgets/thread/trip_detail_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _MockNegotiationBloc
    extends MockBloc<NegotiationEvent, NegotiationState>
    implements NegotiationBloc {}

LinkedTripSummary _trip() => const LinkedTripSummary(
      announcementId: 'ann-1',
      departureCity: 'Paris',
      arrivalCity: 'Dakar',
      departureDate: '2026-06-12',
      departureTime: '14:30',
      transportMode: 'PLANE',
      pickupAddressLabel: 'Gare de Lyon, Paris',
      deliveryAddressLabel: 'Plateau, Dakar',
      availableKg: 18,
      description: 'Remise possible la veille au soir.',
    );

void main() {
  late _MockNegotiationBloc bloc;

  setUp(() {
    bloc = _MockNegotiationBloc();
    when(() => bloc.state).thenReturn(const NegotiationInitial());
    when(() => bloc.stream)
        .thenAnswer((_) => const Stream<NegotiationState>.empty());
  });

  Future<void> openSheet(
    WidgetTester tester, {
    required bool isSender,
    LinkedTripSummary? trip,
  }) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () => TripDetailBottomSheet.show(
            context,
            trip: trip ?? _trip(),
            isSender: isSender,
            bloc: bloc,
            threadId: 't-1',
          ),
          child: const Text('Ouvrir'),
        ),
      ),
    ));
    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();
  }

  group('TripDetailBottomSheet', () {
    testWidgets('affiche le titre et l\'itinéraire', (tester) async {
      await openSheet(tester, isSender: true);
      expect(find.text('Trajet lié'), findsOneWidget);
      expect(find.text('Paris'), findsOneWidget);
      expect(find.text('Dakar'), findsOneWidget);
    });

    testWidgets('affiche les adresses remise et livraison', (tester) async {
      await openSheet(tester, isSender: true);
      expect(find.textContaining('Gare de Lyon, Paris'), findsOneWidget);
      expect(find.textContaining('Plateau, Dakar'), findsOneWidget);
    });

    testWidgets('affiche la note du voyageur', (tester) async {
      await openSheet(tester, isSender: true);
      expect(
          find.text('Remise possible la veille au soir.'), findsOneWidget);
    });

    testWidgets('côté expéditeur → bouton "Refuser le trajet" présent',
        (tester) async {
      await openSheet(tester, isSender: true);
      expect(find.text('Refuser le trajet'), findsOneWidget);
    });

    testWidgets('côté voyageur → pas de bouton "Refuser le trajet"',
        (tester) async {
      await openSheet(tester, isSender: false);
      expect(find.text('Refuser le trajet'), findsNothing);
    });

    testWidgets('tap "Refuser le trajet" ouvre le sheet de raison',
        (tester) async {
      await openSheet(tester, isSender: true);
      await tester.tap(find.text('Refuser le trajet'));
      await tester.pumpAndSettle();
      expect(find.text('Refuser ce trajet'), findsOneWidget);
    });

    testWidgets('gère les champs nullables sans crash', (tester) async {
      await openSheet(
        tester,
        isSender: true,
        trip: const LinkedTripSummary(announcementId: 'ann-x'),
      );
      expect(find.text('Trajet lié'), findsOneWidget);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/package_request/presentation/widgets/thread/trip_detail_bottom_sheet_test.dart`
Expected: FAIL — `trip_detail_bottom_sheet.dart` introuvable.

- [ ] **Step 3: Write the widget**

Create `lib/features/package_request/presentation/widgets/thread/trip_detail_bottom_sheet.dart` :

```dart
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/design/widgets/dony_bottom_sheet.dart';
import 'package:dony/core/design/widgets/dony_button.dart';
import 'package:dony/features/package_request/bloc/negotiation_bloc.dart';
import 'package:dony/features/package_request/data/models/linked_trip_summary.dart';
import 'package:dony/features/package_request/presentation/_theme.dart';
import 'package:dony/features/package_request/presentation/widgets/thread/refuse_trip_bottom_sheet.dart';
import 'package:flutter/material.dart';

/// Bottom sheet affichant le détail du trajet lié à une négociation, sous
/// forme de timeline départ → arrivée.
///
/// Côté expéditeur ([isSender] == true), un bouton destructif « Refuser le
/// trajet » est affiché : il ferme ce sheet et ouvre [RefuseTripBottomSheet].
class TripDetailBottomSheet {
  const TripDetailBottomSheet._();

  static Future<void> show(
    BuildContext context, {
    required LinkedTripSummary trip,
    required bool isSender,
    required NegotiationBloc bloc,
    required String threadId,
  }) {
    return DonyBottomSheet.show<void>(
      context,
      title: 'Trajet lié',
      child: _TripDetailContent(trip: trip),
      stickyBottom: isSender
          ? DonyButton(
              label: 'Refuser le trajet',
              variant: DonyButtonVariant.destructive,
              onPressed: () {
                Navigator.of(context, rootNavigator: true).pop();
                RefuseTripBottomSheet.show(
                  context,
                  bloc: bloc,
                  threadId: threadId,
                );
              },
            )
          : null,
    );
  }
}

class _TripDetailContent extends StatelessWidget {
  const _TripDetailContent({required this.trip});
  final LinkedTripSummary trip;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[
      if (trip.transportMode != null)
        _Chip(
          text: '${_transportIcon(trip.transportMode)} '
              '${_transportLabel(trip.transportMode)}',
          highlighted: true,
        ),
      if (trip.availableKg != null)
        _Chip(text: '⚖️ ${trip.availableKg} kg dispo'),
      if (trip.departureDate != null)
        _Chip(text: '📅 ${_formatDate(trip.departureDate!)}'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (chips.isNotEmpty) ...[
          Wrap(
            spacing: DonySpacing.sm,
            runSpacing: DonySpacing.sm,
            children: chips,
          ),
          const SizedBox(height: DonySpacing.lg),
        ],
        _Timeline(trip: trip),
        if (trip.description != null && trip.description!.isNotEmpty) ...[
          const SizedBox(height: DonySpacing.base),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(DonySpacing.md),
            decoration: BoxDecoration(
              color: DonyColors.sand100,
              borderRadius: BorderRadius.circular(DonyRadius.md),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'NOTE DU VOYAGEUR',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: kTextSecondary,
                        letterSpacing: 0.6,
                      ),
                ),
                const SizedBox(height: DonySpacing.xs),
                Text(
                  trip.description!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: DonyColors.textPrimary,
                        height: 1.4,
                      ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  static String _transportIcon(String? mode) => switch (mode) {
        'PLANE' => '✈️',
        'TRAIN' => '🚄',
        'CAR' => '🚗',
        _ => '📦',
      };

  static String _transportLabel(String? mode) => switch (mode) {
        'PLANE' => 'Avion',
        'TRAIN' => 'Train',
        'CAR' => 'Voiture',
        _ => 'Transport',
      };

  static String _formatDate(String isoDate) {
    try {
      final d = DateTime.parse(isoDate);
      const months = [
        '', 'janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin',
        'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.',
      ];
      return '${d.day} ${months[d.month]} ${d.year}';
    } catch (_) {
      return isoDate;
    }
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text, this.highlighted = false});
  final String text;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: highlighted ? DonyColors.blue50 : DonyColors.sand100,
        borderRadius: BorderRadius.circular(DonyRadius.xl),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: highlighted ? DonyColors.primary : kTextSecondary,
            ),
      ),
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.trip});
  final LinkedTripSummary trip;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              const SizedBox(height: 4),
              Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  color: DonyColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
              Expanded(
                child: Container(width: 2, color: DonyColors.neutral200),
              ),
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: DonyColors.primary, width: 3),
                ),
              ),
            ],
          ),
          const SizedBox(width: DonySpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Endpoint(
                  label: trip.departureTime != null
                      ? 'DÉPART · ${trip.departureTime}'
                      : 'DÉPART',
                  city: trip.departureCity ?? '—',
                  address: trip.pickupAddressLabel,
                  addressIcon: '📍',
                ),
                const SizedBox(height: DonySpacing.lg),
                _Endpoint(
                  label: 'ARRIVÉE',
                  city: trip.arrivalCity ?? '—',
                  address: trip.deliveryAddressLabel,
                  addressIcon: '🏠',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Endpoint extends StatelessWidget {
  const _Endpoint({
    required this.label,
    required this.city,
    required this.addressIcon,
    this.address,
  });
  final String label;
  final String city;
  final String addressIcon;
  final String? address;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: tt.bodySmall?.copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: kTextSecondary,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          city,
          style: tt.titleMedium?.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: DonyColors.textPrimary,
          ),
        ),
        if (address != null && address!.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            '$addressIcon $address',
            style: tt.bodyMedium?.copyWith(
              fontSize: 13,
              color: kTextSecondary,
            ),
          ),
        ],
      ],
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/package_request/presentation/widgets/thread/trip_detail_bottom_sheet_test.dart`
Expected: PASS (7 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/package_request/presentation/widgets/thread/trip_detail_bottom_sheet.dart \
        test/features/package_request/presentation/widgets/thread/trip_detail_bottom_sheet_test.dart
git commit -m "$(cat <<'EOF'
feat(negotiation): TripDetailBottomSheet — timeline du trajet lié

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 7: Hero card cliquable + affordance « Voir le trajet lié »

**Files:**
- Modify: `lib/features/package_request/presentation/widgets/thread/thread_hero_card.dart`
- Test: `test/features/package_request/presentation/widgets/thread/thread_hero_card_test.dart`

- [ ] **Step 1: Write the failing test**

Dans `test/features/package_request/presentation/widgets/thread/thread_hero_card_test.dart`, ajouter ce groupe à l'intérieur de `void main() { ... }`, à la fin (avant la dernière `}`):

```dart
  group('ThreadHeroCard onTap', () {
    testWidgets('sans onTap → pas d\'affordance "Voir le trajet lié"',
        (tester) async {
      await tester.pumpWidget(wrap(ThreadHeroCard(
        thread: _thread(status: NegotiationThreadStatus.awaitingPayment),
        statusVariant: ThreadStatusVariant.awaitingPayment,
      )));
      expect(find.text('Voir le trajet lié'), findsNothing);
    });

    testWidgets('avec onTap → affordance affichée et tap déclenché',
        (tester) async {
      var tapped = false;
      await tester.pumpWidget(wrap(ThreadHeroCard(
        thread: _thread(status: NegotiationThreadStatus.awaitingPayment),
        statusVariant: ThreadStatusVariant.awaitingPayment,
        onTap: () => tapped = true,
      )));
      expect(find.text('Voir le trajet lié'), findsOneWidget);

      await tester.tap(find.text('Voir le trajet lié'));
      await tester.pump();
      expect(tapped, isTrue);
    });
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/package_request/presentation/widgets/thread/thread_hero_card_test.dart --plain-name "onTap"`
Expected: FAIL — `No named parameter with the name 'onTap'`.

- [ ] **Step 3: Add the `onTap` parameter and affordance**

Dans `lib/features/package_request/presentation/widgets/thread/thread_hero_card.dart` :

a. Dans la classe `ThreadHeroCard`, ajouter le paramètre au constructeur (après `required this.statusVariant,`) :

```dart
    this.onTap,
```

b. Ajouter le champ après `final ThreadStatusVariant statusVariant;` :

```dart

  /// Si non null, le card devient cliquable et affiche une affordance
  /// « Voir le trajet lié » en bas.
  final VoidCallback? onTap;
```

c. Remplacer entièrement la méthode `build` par :

```dart
  @override
  Widget build(BuildContext context) {
    final card = Container(
      margin: const EdgeInsets.fromLTRB(
          DonySpacing.base, DonySpacing.md, DonySpacing.base, DonySpacing.sm),
      decoration: BoxDecoration(
        gradient: statusVariant.gradient,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        boxShadow: [
          BoxShadow(
            color: statusVariant.shadowColor.withValues(alpha: 0.30),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.antiAlias,
        children: [
          // Glow circle décoration top-right
          Positioned(
            top: -24,
            right: -24,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.07),
              ),
            ),
          ),
          // Contenu
          Padding(
            padding: const EdgeInsets.all(DonySpacing.base),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(DonySpacing.sm),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(statusVariant.icon,
                          color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: DonySpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            statusVariant.priceLabel,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium!
                                .copyWith(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white.withValues(alpha: 0.70),
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${thread.currentPriceEur.toStringAsFixed(0)} €',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium!
                                .copyWith(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.5,
                              height: 1.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _StatusBadge(label: statusVariant.badge),
                  ],
                ),
                const SizedBox(height: 14),
                _RoundProgress(roundsCount: thread.roundsCount, max: 5),
                if (onTap != null) ...[
                  const SizedBox(height: 12),
                  const _ViewTripHint(),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return card;
    return GestureDetector(onTap: onTap, child: card);
  }
```

d. Ajouter cette nouvelle classe à la fin du fichier (après `_RoundProgress`) :

```dart
class _ViewTripHint extends StatelessWidget {
  const _ViewTripHint();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.local_shipping_outlined,
              size: 15, color: Colors.white.withValues(alpha: 0.85)),
          const SizedBox(width: 6),
          Text(
            'Voir le trajet lié',
            style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
          ),
          const Spacer(),
          Icon(Icons.chevron_right_rounded,
              size: 18, color: Colors.white.withValues(alpha: 0.85)),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/package_request/presentation/widgets/thread/thread_hero_card_test.dart`
Expected: PASS (tous les tests du fichier).

- [ ] **Step 5: Commit**

```bash
git add lib/features/package_request/presentation/widgets/thread/thread_hero_card.dart \
        test/features/package_request/presentation/widgets/thread/thread_hero_card_test.dart
git commit -m "$(cat <<'EOF'
feat(negotiation): hero card cliquable avec affordance « Voir le trajet lié »

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 8: Bandeau « Trajet refusé » dans `ThreadMessageBubble`

**Files:**
- Modify: `lib/features/package_request/presentation/widgets/thread/thread_message_bubble.dart`
- Test: `test/features/package_request/presentation/widgets/thread/thread_message_bubble_test.dart`

- [ ] **Step 1: Write the failing test**

Dans `test/features/package_request/presentation/widgets/thread/thread_message_bubble_test.dart`, ajouter ce groupe à l'intérieur de `void main() { ... }`, à la fin (avant la dernière `}`):

```dart
  group('ThreadMessageBubble isTripRefusal', () {
    testWidgets('isTripRefusal=true → bandeau "Trajet refusé" + raison',
        (tester) async {
      await tester.pumpWidget(wrap(ThreadMessageBubble(
        message: _msg(
          kind: NegotiationMessageKind.reject,
          price: null,
          body: 'Date trop tardive',
        ),
        mine: false,
        isTripRefusal: true,
      )));
      expect(
          find.text('Trajet refusé par l\'expéditeur'), findsOneWidget);
      expect(find.textContaining('Date trop tardive'), findsOneWidget);
      expect(find.text('REJETÉE'), findsNothing);
    });

    testWidgets('isTripRefusal=false → bulle "REJETÉE" classique',
        (tester) async {
      await tester.pumpWidget(wrap(ThreadMessageBubble(
        message: _msg(
          kind: NegotiationMessageKind.reject,
          price: null,
          body: 'Date trop tardive',
        ),
        mine: false,
      )));
      expect(find.text('REJETÉE'), findsOneWidget);
      expect(
          find.text('Trajet refusé par l\'expéditeur'), findsNothing);
    });
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/package_request/presentation/widgets/thread/thread_message_bubble_test.dart --plain-name "isTripRefusal"`
Expected: FAIL — `No named parameter with the name 'isTripRefusal'`.

- [ ] **Step 3: Add the `isTripRefusal` parameter and banner**

Dans `lib/features/package_request/presentation/widgets/thread/thread_message_bubble.dart` :

a. Dans le constructeur `ThreadMessageBubble`, ajouter après `this.highlight = false,` :

```dart
    this.isTripRefusal = false,
```

b. Ajouter le champ après `final bool highlight;` (et sa doc) :

```dart

  /// Si `true`, le message (kind REJECT) est rendu comme un bandeau
  /// « Trajet refusé par l'expéditeur » au lieu de la bulle « REJETÉE ».
  final bool isTripRefusal;
```

c. Au tout début de la méthode `build`, ajouter avant la déclaration `final radius = ...` :

```dart
    if (isTripRefusal) return _buildTripRefusalBanner(context);

```

d. Ajouter cette méthode dans la classe, juste avant `String _kindLabel(...)` :

```dart
  Widget _buildTripRefusalBanner(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(DonySpacing.md),
      decoration: BoxDecoration(
        color: DonyColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(DonyRadius.md),
        border: Border.all(color: DonyColors.error.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.error_outline_rounded,
                  size: 16, color: DonyColors.error),
              const SizedBox(width: 6),
              Text(
                'Trajet refusé par l\'expéditeur',
                style: tt.bodyMedium!.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: DonyColors.error,
                ),
              ),
            ],
          ),
          if (message.body != null && message.body!.isNotEmpty) ...[
            const SizedBox(height: DonySpacing.xs),
            Text(
              '« ${message.body!} »',
              style: tt.bodyMedium!.copyWith(
                fontSize: 13.5,
                color: kTextPrimary,
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: DonySpacing.xs),
          Text(
            DateFormat('HH:mm').format(message.createdAt),
            style: tt.bodyMedium!.copyWith(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: kTextHint,
            ),
          ),
        ],
      ),
    );
  }

```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/package_request/presentation/widgets/thread/thread_message_bubble_test.dart`
Expected: PASS (tous les tests du fichier).

- [ ] **Step 5: Commit**

```bash
git add lib/features/package_request/presentation/widgets/thread/thread_message_bubble.dart \
        test/features/package_request/presentation/widgets/thread/thread_message_bubble_test.dart
git commit -m "$(cat <<'EOF'
feat(negotiation): bandeau « Trajet refusé » dans ThreadMessageBubble

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 9: Câblage dans `NegotiationThreadScreen`

Brancher l'ouverture du sheet sur le hero card et le flag `isTripRefusal` sur les bulles.

**Files:**
- Modify: `lib/features/package_request/presentation/screens/shared/negotiation_thread_screen.dart`
- Test: `test/features/package_request/presentation/screens/shared/negotiation_thread_screen_test.dart`

- [ ] **Step 1: Write the failing test**

Dans `test/features/package_request/presentation/screens/shared/negotiation_thread_screen_test.dart` :

a. Ajouter l'import en haut, après l'import de `negotiation_thread.dart` :

```dart
import 'package:dony/features/package_request/data/models/linked_trip_summary.dart';
```

b. Ajouter ce groupe à l'intérieur de `void main() { ... }`, à la fin (avant la dernière `}`), à l'intérieur du `group('NegotiationThreadScreen', ...)` — soit juste avant la `});` qui ferme ce groupe :

```dart
    testWidgets(
        'hero card cliquable au statut AWAITING_PAYMENT côté expéditeur '
        'avec trajet lié', (tester) async {
      final thread = NegotiationThread(
        id: 't-1',
        packageRequestId: 'pr-1',
        travelerId: 'tr-1',
        travelerTravelDate: DateTime(2026, 6, 15),
        travelerAvailableKg: 10,
        status: NegotiationThreadStatus.awaitingPayment,
        currentPriceEur: 68,
        roundsCount: 3,
        lastActivityAt: DateTime(2026, 5, 10),
        createdAt: DateTime(2026, 5, 10),
        messages: const [],
        linkedTrip: const LinkedTripSummary(
          announcementId: 'ann-1',
          departureCity: 'Paris',
          arrivalCity: 'Dakar',
        ),
      );
      when(() => bloc.state).thenReturn(NegotiationLoaded(thread));
      await tester.pumpWidget(wrap(viewerUserId: 'sender-1'));
      await tester.pumpAndSettle();

      expect(find.text('Voir le trajet lié'), findsOneWidget);

      await tester.tap(find.text('Voir le trajet lié'));
      await tester.pumpAndSettle();
      expect(find.text('Trajet lié'), findsOneWidget);
    });

    testWidgets(
        'hero card non cliquable côté voyageur même avec trajet lié',
        (tester) async {
      final thread = NegotiationThread(
        id: 't-1',
        packageRequestId: 'pr-1',
        travelerId: 'tr-1',
        travelerTravelDate: DateTime(2026, 6, 15),
        travelerAvailableKg: 10,
        status: NegotiationThreadStatus.awaitingPayment,
        currentPriceEur: 68,
        roundsCount: 3,
        lastActivityAt: DateTime(2026, 5, 10),
        createdAt: DateTime(2026, 5, 10),
        messages: const [],
        linkedTrip: const LinkedTripSummary(announcementId: 'ann-1'),
      );
      when(() => bloc.state).thenReturn(NegotiationLoaded(thread));
      await tester.pumpWidget(wrap(viewerUserId: 'tr-1'));
      await tester.pumpAndSettle();

      expect(find.text('Voir le trajet lié'), findsNothing);
    });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/package_request/presentation/screens/shared/negotiation_thread_screen_test.dart --plain-name "hero card"`
Expected: FAIL — soit l'affordance n'apparaît pas, soit le champ `linkedTrip` n'est pas reconnu (selon l'ordre des tâches, le câblage n'existe pas encore).

- [ ] **Step 3: Wire the hero card `onTap`**

Dans `lib/features/package_request/presentation/screens/shared/negotiation_thread_screen.dart` :

a. Ajouter l'import après l'import de `thread_state_cta_bar.dart` :

```dart
import 'package:dony/features/package_request/presentation/widgets/thread/trip_detail_bottom_sheet.dart';
```

b. Dans `_LoadedView.build`, après la ligne
`final isLastFromOther = ...;` et avant le `return Column(`, ajouter :

```dart
    final isSender = thread.travelerId != viewerUserId;
    final canViewTrip =
        thread.status == NegotiationThreadStatus.awaitingPayment &&
            isSender &&
            thread.linkedTrip != null;
```

c. Remplacer la ligne
`ThreadHeroCard(thread: thread, statusVariant: variant)`
par :

```dart
        ThreadHeroCard(
          thread: thread,
          statusVariant: variant,
          onTap: canViewTrip
              ? () => TripDetailBottomSheet.show(
                    context,
                    trip: thread.linkedTrip!,
                    isSender: true,
                    bloc: context.read<NegotiationBloc>(),
                    threadId: thread.id,
                  )
              : null,
        )
```

(Le reste de la chaîne `.animate().fadeIn(...)...` reste inchangé.)

- [ ] **Step 4: Wire the `isTripRefusal` flag on bubbles**

Toujours dans `_LoadedView.build`, dans le `itemBuilder` du `ListView.builder`, après la ligne
`final shouldHighlight = ...;` (qui se termine par `_isProposalOrCounter(m.kind);`), ajouter :

```dart
                final isTripRefusal =
                    m.kind == NegotiationMessageKind.reject &&
                        thread.status != NegotiationThreadStatus.rejected &&
                        thread.status !=
                            NegotiationThreadStatus.autoRejected;
```

Puis, dans le `return ThreadMessageBubble(...)`, ajouter le paramètre après `highlight: shouldHighlight,` :

```dart
                  isTripRefusal: isTripRefusal,
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/features/package_request/presentation/screens/shared/negotiation_thread_screen_test.dart`
Expected: PASS (tous les tests du fichier).

- [ ] **Step 6: Commit**

```bash
git add lib/features/package_request/presentation/screens/shared/negotiation_thread_screen.dart \
        test/features/package_request/presentation/screens/shared/negotiation_thread_screen_test.dart
git commit -m "$(cat <<'EOF'
feat(negotiation): câblage du sheet trajet lié + bandeau refus dans l'écran

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 10: Vérification finale

**Files:** aucun (vérification globale).

- [ ] **Step 1: Lancer l'analyse statique**

Run: `flutter analyze`
Expected: `No issues found!` — corriger tout warning/erreur introduit par les tâches précédentes avant de continuer.

- [ ] **Step 2: Lancer toute la suite de tests**

Run: `flutter test`
Expected: tous les tests passent (0 rouge).

- [ ] **Step 3: Vérifier la couverture**

Run: `flutter test --coverage`
Puis vérifier que la couverture globale reste ≥ 90 % (règle projet). Les fichiers
créés (`linked_trip_summary.dart`, `trip_detail_bottom_sheet.dart`,
`refuse_trip_bottom_sheet.dart`) et les modifications doivent être couverts par
les tests des tâches 1 à 9. Si un fichier passe sous 90 %, ajouter les tests
manquants ciblant les branches non couvertes (champs nullables, états de
chargement) puis recommit.

- [ ] **Step 4: Commit éventuel des tests de couverture**

Si des tests ont été ajoutés à l'étape 3 :

```bash
git add test/
git commit -m "$(cat <<'EOF'
test(negotiation): compléter la couverture du sheet trajet lié

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Self-Review

**Couverture du spec :**
- §2 modèle `LinkedTripSummary` → Task 1. Champ `linkedTrip` → Task 2. ✓
- §3 `refuseTrip` repo → Task 3. Event/handler BLoC → Task 4. ✓
- §4 `TripDetailBottomSheet` → Task 6. `RefuseTripBottomSheet` (raison obligatoire)
  → Task 5. ✓
- §4 hero card cliquable + affordance → Task 7 + câblage Task 9. ✓
- §5 bandeau « Trajet refusé » côté voyageur → Task 8 + flag Task 9. ✓
- §5 re-proposition via CTA existant → aucun code nécessaire (CTA
  « Lier un trajet à cette offre » déjà présent au statut AWAITING_TRIP). ✓
- §6 tests → tests inclus dans chaque tâche + Task 10 (couverture ≥ 90 %). ✓

**Cohérence des types :** `LinkedTripSummary` (champs `announcementId`,
`departureCity`, `arrivalCity`, `departureDate`, `departureTime`,
`transportMode`, `pickupAddressLabel`, `deliveryAddressLabel`, `availableKg`,
`description`) est utilisé de façon identique en Tasks 1, 2, 6, 9.
`NegotiationRefuseTripRequested({threadId, reason})` identique en Tasks 4, 5.
`refuseTrip(id, {reason})` identique en Tasks 3, 4. `onTap` (Task 7) et
`isTripRefusal` (Task 8) consommés en Task 9 avec les mêmes signatures.

**Dépendances entre tâches :** ordre 1→9 respecté — Task 5 (`RefuseTripBottomSheet`)
précède Task 6 qui l'invoque ; Tasks 6, 7, 8 précèdent Task 9 qui les câble.
