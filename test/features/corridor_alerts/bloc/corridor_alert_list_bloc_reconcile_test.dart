// Événements construits à l'exécution : deux instances `const` identiques
// court-circuitent la comparaison Equatable.
// ignore_for_file: prefer_const_constructors

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/corridor_alerts/bloc/corridor_alert_list_bloc.dart';
import 'package:dony/features/corridor_alerts/data/corridor_alert_repository.dart';
import 'package:dony/features/corridor_alerts/data/models/corridor_alert_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/value_equality.dart';

class _MockRepo extends Mock implements CorridorAlertRepository {}

class _MockAnalytics extends Mock implements AnalyticsService {}

CorridorAlertModel _alert(String id, {bool active = true, int matches = 1}) =>
    CorridorAlertModel(
      id: id,
      departureCity: 'Paris',
      arrivalCity: 'Bamako',
      active: active,
      matchCount: matches,
      createdAt: DateTime(2026, 6, 20),
    );

void main() {
  late _MockRepo repo;
  late _MockAnalytics analytics;

  setUpAll(() {
    registerFallbackValue(
      const CorridorAlertDraft(departureCity: 'x', arrivalCity: 'y'),
    );
  });

  setUp(() {
    repo = _MockRepo();
    analytics = _MockAnalytics();
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
  });

  group('événements — égalité de valeur', () {
    test('bascule : identifiant et état actif', () {
      expectValueEquality(() => CorridorAlertActiveToggled('a1', true), [
        CorridorAlertActiveToggled('a1', false),
        CorridorAlertActiveToggled('a2', true),
      ]);
    });

    test('suppression : identifiant', () {
      expectValueEquality(() => CorridorAlertDeleted('a1'), [
        CorridorAlertDeleted('a2'),
      ]);
    });

    test('chargement : sans champ', () {
      expectValueEquality(() => CorridorAlertListRequested(), [
        CorridorAlertDeleted('a1'),
      ]);
      expect(CorridorAlertListRequested().props, isEmpty);
    });
  });

  blocTest<CorridorAlertListBloc, CorridorAlertListState>(
    'bascule : mise à jour optimiste puis réconciliation du nombre de '
    'correspondances renvoyé par le serveur',
    build: () {
      when(
        () => repo.update('a1', any(), active: true),
      ).thenAnswer((_) async => _alert('a1', matches: 7));
      return CorridorAlertListBloc(repo, analytics);
    },
    seed: () => CorridorAlertListState(
      status: CorridorAlertListStatus.loaded,
      alerts: [_alert('a1', active: false), _alert('a2')],
    ),
    act: (b) => b.add(CorridorAlertActiveToggled('a1', true)),
    expect: () => [
      isA<CorridorAlertListState>()
          .having((s) => s.alerts.first.active, 'optimiste', isTrue)
          .having((s) => s.alerts.first.matchCount, 'matchCount', 1),
      isA<CorridorAlertListState>()
          .having((s) => s.alerts.first.active, 'active', isTrue)
          .having((s) => s.alerts.first.matchCount, 'matchCount', 7)
          .having((s) => s.alerts.last.matchCount, 'autre intacte', 1),
    ],
    verify: (_) => verify(
      () => analytics.logEvent(
        AnalyticsEvents.corridorAlertToggled,
        properties: {'active': true},
      ),
    ).called(1),
  );
}
