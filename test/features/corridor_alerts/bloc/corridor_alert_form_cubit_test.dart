import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/corridor_alerts/bloc/corridor_alert_form_cubit.dart';
import 'package:dony/features/corridor_alerts/data/corridor_alert_repository.dart';
import 'package:dony/features/corridor_alerts/data/models/alert_direction.dart';
import 'package:dony/features/corridor_alerts/data/models/corridor_alert_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockRepo extends Mock implements CorridorAlertRepository {}

class MockAnalytics extends Mock implements AnalyticsService {}

CorridorAlertModel _created() => CorridorAlertModel(
      id: 'a1',
      departureCity: 'Paris',
      arrivalCity: 'Bamako',
      active: true,
      createdAt: DateTime(2026, 6, 20),
    );

CorridorAlertModel _alert({
  AlertDirection direction = AlertDirection.travelerWantsPackages,
}) =>
    CorridorAlertModel(
      id: 'a1',
      departureCity: 'Paris',
      arrivalCity: 'Dakar',
      active: true,
      createdAt: DateTime(2026, 6, 20),
      direction: direction,
    );

void main() {
  late MockRepo repo;
  late MockAnalytics analytics;

  setUpAll(() {
    registerFallbackValue(const CorridorAlertDraft(
      departureCity: 'x',
      arrivalCity: 'y',
    ));
  });

  setUp(() {
    repo = MockRepo();
    analytics = MockAnalytics();
    when(() => analytics.logEvent(any(), properties: any(named: 'properties')))
        .thenAnswer((_) async {});
  });

  test('initial create state is invalid (no corridor)', () {
    final c = CorridorAlertFormCubit(repo, analytics);
    expect(c.state.isValid, isFalse);
  });

  test('editing seeds state from the alert and is valid', () {
    final c = CorridorAlertFormCubit(repo, analytics, editing: _created());
    expect(c.state.departureCity, 'Paris');
    expect(c.state.arrivalCity, 'Bamako');
    expect(c.state.isValid, isTrue);
  });

  blocTest<CorridorAlertFormCubit, CorridorAlertFormState>(
    'becomes valid once both cities set',
    build: () => CorridorAlertFormCubit(repo, analytics),
    act: (c) {
      c.setDeparture('Paris', 'FR');
      c.setArrival('Bamako', 'ML');
    },
    verify: (c) => expect(c.state.isValid, isTrue),
  );

  blocTest<CorridorAlertFormCubit, CorridorAlertFormState>(
    'submit (create) → submitting then success',
    build: () {
      when(() => repo.create(any())).thenAnswer((_) async => _created());
      return CorridorAlertFormCubit(repo, analytics);
    },
    act: (c) async {
      c.setDeparture('Paris', 'FR');
      c.setArrival('Bamako', 'ML');
      await c.submit();
    },
    expect: () => [
      // setDeparture → departure set, arrival still null → invalid
      isA<CorridorAlertFormState>()
          .having((s) => s.departureCity, 'dep', 'Paris')
          .having((s) => s.isValid, 'valid', isFalse),
      // setArrival → both set → valid
      isA<CorridorAlertFormState>().having((s) => s.isValid, 'valid', isTrue),
      isA<CorridorAlertFormState>().having(
          (s) => s.status, 'status', CorridorAlertFormStatus.submitting),
      isA<CorridorAlertFormState>().having(
          (s) => s.status, 'status', CorridorAlertFormStatus.success),
    ],
  );

  blocTest<CorridorAlertFormCubit, CorridorAlertFormState>(
    'submit (edit) calls update with id',
    build: () {
      when(() => repo.update('a1', any()))
          .thenAnswer((_) async => _created());
      return CorridorAlertFormCubit(repo, analytics, editing: _created());
    },
    act: (c) => c.submit(),
    verify: (_) => verify(() => repo.update('a1', any())).called(1),
  );

  blocTest<CorridorAlertFormCubit, CorridorAlertFormState>(
    'setDateWindow stores dateFrom and dateTo',
    build: () => CorridorAlertFormCubit(repo, analytics),
    act: (c) => c.setDateWindow(DateTime(2026, 7, 5), DateTime(2026, 7, 20)),
    verify: (c) {
      expect(c.state.dateFrom, DateTime(2026, 7, 5));
      expect(c.state.dateTo, DateTime(2026, 7, 20));
    },
  );

  blocTest<CorridorAlertFormCubit, CorridorAlertFormState>(
    'clearDateWindow resets dateFrom and dateTo to null',
    build: () {
      final c = CorridorAlertFormCubit(repo, analytics);
      c.setDateWindow(DateTime(2026, 7, 5), DateTime(2026, 7, 20));
      return c;
    },
    act: (c) => c.clearDateWindow(),
    verify: (c) {
      expect(c.state.dateFrom, isNull);
      expect(c.state.dateTo, isNull);
    },
  );

  blocTest<CorridorAlertFormCubit, CorridorAlertFormState>(
    'editing seeds dateFrom and dateTo from existing alert',
    build: () {
      final alert = CorridorAlertModel(
        id: 'b1',
        departureCity: 'Lyon',
        arrivalCity: 'Dakar',
        active: true,
        createdAt: DateTime(2026, 6, 20),
        dateFrom: DateTime(2026, 8, 10),
        dateTo: DateTime(2026, 8, 25),
      );
      return CorridorAlertFormCubit(repo, analytics, editing: alert);
    },
    verify: (c) {
      expect(c.state.dateFrom, DateTime(2026, 8, 10));
      expect(c.state.dateTo, DateTime(2026, 8, 25));
    },
  );

  // ---------------------------------------------------------------------------
  // Task 2 — direction field
  // ---------------------------------------------------------------------------

  test('initialDirection seeds state.direction on create', () {
    final cubit = CorridorAlertFormCubit(repo, analytics,
        initialDirection: AlertDirection.senderWantsTrips);
    expect(cubit.state.direction, AlertDirection.senderWantsTrips);
  });

  test('editing alert seeds state.direction from alert', () {
    final cubit = CorridorAlertFormCubit(repo, analytics,
        editing: _alert(direction: AlertDirection.senderWantsTrips));
    expect(cubit.state.direction, AlertDirection.senderWantsTrips);
    expect(cubit.isEditing, isTrue);
  });

  blocTest<CorridorAlertFormCubit, CorridorAlertFormState>(
    'setDirection updates state',
    build: () => CorridorAlertFormCubit(repo, analytics),
    act: (c) => c.setDirection(AlertDirection.senderWantsTrips),
    expect: () => [
      isA<CorridorAlertFormState>()
          .having((s) => s.direction, 'direction',
              AlertDirection.senderWantsTrips),
    ],
  );

  blocTest<CorridorAlertFormCubit, CorridorAlertFormState>(
    'submit sends direction in draft',
    build: () => CorridorAlertFormCubit(repo, analytics,
        initialDirection: AlertDirection.senderWantsTrips),
    setUp: () => when(() => repo.create(any()))
        .thenAnswer((_) async => _alert(direction: AlertDirection.senderWantsTrips)),
    act: (c) {
      c.setDeparture('Paris', 'FR');
      c.setArrival('Dakar', 'SN');
      return c.submit();
    },
    verify: (_) {
      final draft = verify(() => repo.create(captureAny())).captured.single
          as CorridorAlertDraft;
      expect(draft.direction, AlertDirection.senderWantsTrips);
    },
  );

  blocTest<CorridorAlertFormCubit, CorridorAlertFormState>(
    'submit error → status error',
    build: () {
      when(() => repo.create(any())).thenThrow(Exception('422'));
      return CorridorAlertFormCubit(repo, analytics);
    },
    act: (c) async {
      c.setDeparture('Paris', 'FR');
      c.setArrival('Bamako', 'ML');
      await c.submit();
    },
    expect: () => [
      // setDeparture
      isA<CorridorAlertFormState>()
          .having((s) => s.departureCity, 'dep', 'Paris')
          .having((s) => s.isValid, 'valid', isFalse),
      // setArrival → valid
      isA<CorridorAlertFormState>().having((s) => s.isValid, 'valid', isTrue),
      isA<CorridorAlertFormState>().having(
          (s) => s.status, 'status', CorridorAlertFormStatus.submitting),
      isA<CorridorAlertFormState>()
          .having((s) => s.status, 'status', CorridorAlertFormStatus.error)
          .having((s) => s.errorMessage, 'err', isNotNull),
    ],
  );
}
