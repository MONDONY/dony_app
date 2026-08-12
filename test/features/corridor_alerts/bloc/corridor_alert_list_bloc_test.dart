import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/features/corridor_alerts/bloc/corridor_alert_list_bloc.dart';
import 'package:dony/features/corridor_alerts/data/corridor_alert_repository.dart';
import 'package:dony/features/corridor_alerts/data/models/corridor_alert_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mocktail/mocktail.dart';

class MockRepo extends Mock implements CorridorAlertRepository {}

class MockAnalytics extends Mock implements AnalyticsService {}

class MockHiveService extends Mock implements HiveService {}

class MockBox extends Mock implements Box {}

CorridorAlertModel _alert(String id, {bool active = true}) =>
    CorridorAlertModel(
      id: id,
      departureCity: 'Paris',
      arrivalCity: 'Bamako',
      active: active,
      matchCount: 1,
      createdAt: DateTime(2026, 6, 20),
    );

void main() {
  late MockRepo repo;
  late MockAnalytics analytics;

  setUpAll(() {
    registerFallbackValue(
      const CorridorAlertDraft(departureCity: 'x', arrivalCity: 'y'),
    );
  });

  setUp(() {
    repo = MockRepo();
    analytics = MockAnalytics();
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
  });

  blocTest<CorridorAlertListBloc, CorridorAlertListState>(
    'CorridorAlertListRequested → loading then loaded',
    build: () {
      when(
        () => repo.getMyAlerts(),
      ).thenAnswer((_) async => [_alert('a1'), _alert('a2')]);
      return CorridorAlertListBloc(repo, analytics);
    },
    act: (b) => b.add(CorridorAlertListRequested()),
    expect: () => [
      isA<CorridorAlertListState>().having(
        (s) => s.status,
        'status',
        CorridorAlertListStatus.loading,
      ),
      isA<CorridorAlertListState>()
          .having((s) => s.status, 'status', CorridorAlertListStatus.loaded)
          .having((s) => s.alerts.length, 'len', 2),
    ],
  );

  blocTest<CorridorAlertListBloc, CorridorAlertListState>(
    'load error → status error',
    build: () {
      when(() => repo.getMyAlerts()).thenThrow(Exception('boom'));
      return CorridorAlertListBloc(repo, analytics);
    },
    act: (b) => b.add(CorridorAlertListRequested()),
    expect: () => [
      isA<CorridorAlertListState>().having(
        (s) => s.status,
        'status',
        CorridorAlertListStatus.loading,
      ),
      isA<CorridorAlertListState>()
          .having((s) => s.status, 'status', CorridorAlertListStatus.error)
          .having((s) => s.errorMessage, 'err', isNotNull),
    ],
  );

  blocTest<CorridorAlertListBloc, CorridorAlertListState>(
    'toggle optimistic: flips active immediately then confirms',
    build: () {
      when(
        () => repo.update(any(), any(), active: any(named: 'active')),
      ).thenAnswer((_) async => _alert('a1', active: false));
      return CorridorAlertListBloc(repo, analytics);
    },
    seed: () => CorridorAlertListState(
      status: CorridorAlertListStatus.loaded,
      alerts: [_alert('a1', active: true)],
    ),
    act: (b) => b.add(const CorridorAlertActiveToggled('a1', false)),
    expect: () => [
      isA<CorridorAlertListState>().having(
        (s) => s.alerts.first.active,
        'active',
        isFalse,
      ),
    ],
    verify: (_) {
      verify(() => repo.update('a1', any(), active: false)).called(1);
    },
  );

  blocTest<CorridorAlertListBloc, CorridorAlertListState>(
    'toggle rollback: restores previous active + status error on failure',
    build: () {
      when(
        () => repo.update(any(), any(), active: any(named: 'active')),
      ).thenThrow(Exception('net'));
      return CorridorAlertListBloc(repo, analytics);
    },
    seed: () => CorridorAlertListState(
      status: CorridorAlertListStatus.loaded,
      alerts: [_alert('a1', active: true)],
    ),
    act: (b) => b.add(const CorridorAlertActiveToggled('a1', false)),
    expect: () => [
      // optimistic flip to false
      isA<CorridorAlertListState>().having(
        (s) => s.alerts.first.active,
        'active',
        isFalse,
      ),
      // rollback to true + error
      isA<CorridorAlertListState>()
          .having((s) => s.alerts.first.active, 'active', isTrue)
          .having((s) => s.status, 'status', CorridorAlertListStatus.error),
    ],
  );

  blocTest<CorridorAlertListBloc, CorridorAlertListState>(
    'delete optimistic: removes immediately',
    build: () {
      when(() => repo.delete('a1')).thenAnswer((_) async {});
      return CorridorAlertListBloc(repo, analytics);
    },
    seed: () => CorridorAlertListState(
      status: CorridorAlertListStatus.loaded,
      alerts: [_alert('a1'), _alert('a2')],
    ),
    act: (b) => b.add(const CorridorAlertDeleted('a1')),
    expect: () => [
      isA<CorridorAlertListState>().having(
        (s) => s.alerts.map((a) => a.id),
        'ids',
        ['a2'],
      ),
    ],
  );

  blocTest<CorridorAlertListBloc, CorridorAlertListState>(
    'delete rollback: restores list + error on failure',
    build: () {
      when(() => repo.delete('a1')).thenThrow(Exception('net'));
      return CorridorAlertListBloc(repo, analytics);
    },
    seed: () => CorridorAlertListState(
      status: CorridorAlertListStatus.loaded,
      alerts: [_alert('a1'), _alert('a2')],
    ),
    act: (b) => b.add(const CorridorAlertDeleted('a1')),
    expect: () => [
      isA<CorridorAlertListState>().having(
        (s) => s.alerts.map((a) => a.id),
        'ids',
        ['a2'],
      ),
      isA<CorridorAlertListState>()
          .having((s) => s.alerts.map((a) => a.id), 'ids', ['a1', 'a2'])
          .having((s) => s.status, 'status', CorridorAlertListStatus.error),
    ],
  );

  // ---------------------------------------------------------------------------
  // Rattrapage kHasActiveCorridorAlert (utilisateurs avec alertes préexistantes
  // à ce feature flag, cf. CorridorAlertFormCubit.submit() pour le même
  // pattern côté création/édition)
  // ---------------------------------------------------------------------------

  group('kHasActiveCorridorAlert (rattrapage au chargement)', () {
    late MockHiveService hive;
    late MockBox box;

    setUp(() {
      hive = MockHiveService();
      box = MockBox();
      when(() => hive.userPrefs).thenReturn(box);
      when(() => box.put(any(), any())).thenAnswer((_) async {});
    });

    blocTest<CorridorAlertListBloc, CorridorAlertListState>(
      'load avec alertes non vides pose le flag si hiveService fourni',
      build: () {
        when(
          () => repo.getMyAlerts(),
        ).thenAnswer((_) async => [_alert('a1'), _alert('a2')]);
        return CorridorAlertListBloc(repo, analytics, hiveService: hive);
      },
      act: (b) => b.add(CorridorAlertListRequested()),
      wait: const Duration(milliseconds: 1),
      verify: (_) {
        verify(
          () => box.put(HiveService.kHasActiveCorridorAlert, true),
        ).called(1);
      },
    );

    blocTest<CorridorAlertListBloc, CorridorAlertListState>(
      'load sans alerte ne pose pas le flag',
      build: () {
        when(() => repo.getMyAlerts()).thenAnswer((_) async => []);
        return CorridorAlertListBloc(repo, analytics, hiveService: hive);
      },
      act: (b) => b.add(CorridorAlertListRequested()),
      wait: const Duration(milliseconds: 1),
      verify: (_) {
        verifyNever(() => box.put(HiveService.kHasActiveCorridorAlert, true));
      },
    );

    blocTest<CorridorAlertListBloc, CorridorAlertListState>(
      'load avec alertes non vides sans hiveService ne lève pas d\'exception',
      build: () {
        when(() => repo.getMyAlerts()).thenAnswer((_) async => [_alert('a1')]);
        return CorridorAlertListBloc(repo, analytics);
      },
      act: (b) => b.add(CorridorAlertListRequested()),
      expect: () => [
        isA<CorridorAlertListState>().having(
          (s) => s.status,
          'status',
          CorridorAlertListStatus.loading,
        ),
        isA<CorridorAlertListState>().having(
          (s) => s.status,
          'status',
          CorridorAlertListStatus.loaded,
        ),
      ],
    );
  });
}
