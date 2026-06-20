import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/corridor_alerts/bloc/corridor_alert_form_cubit.dart';
import 'package:dony/features/corridor_alerts/data/corridor_alert_repository.dart';
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
