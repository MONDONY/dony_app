import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/features/trip_templates/bloc/trip_recurrence_bloc.dart';
import 'package:dony/features/trip_templates/bloc/trip_recurrence_event.dart';
import 'package:dony/features/trip_templates/bloc/trip_recurrence_state.dart';
import 'package:dony/features/trip_templates/bloc/trip_template_bloc.dart';
import 'package:dony/features/trip_templates/bloc/trip_template_event.dart';
import 'package:dony/features/trip_templates/bloc/trip_template_state.dart';
import 'package:dony/features/trip_templates/data/models/trip_template.dart';
import 'package:dony/features/trip_templates/data/repositories/trip_recurrence_repository.dart';
import 'package:dony/features/trip_templates/data/repositories/trip_template_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/mock_analytics_backend.dart';

class _MockTemplateRepo extends Mock implements TripTemplateRepository {}

class _MockRecurrenceRepo extends Mock implements TripRecurrenceRepository {}

const _template = TripTemplate(
  id: 't1',
  label: 'Mon Paris-Dakar',
  departureCity: 'Paris',
  arrivalCity: 'Dakar',
  transportMode: 'PLANE',
  capacityUnit: 'SUITCASE_23KG',
  availableKg: 23,
  pricePerKg: 8,
  acceptedCategories: ['Vêtements'],
);

/// Modèles et trajets récurrents : leur usage n'était pas tracé du tout.
void main() {
  late MockAnalyticsBackend backend;

  setUp(() => backend = MockAnalyticsBackend());

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('modèle créé puis supprimé : trip_template_saved', () async {
    final repo = _MockTemplateRepo();
    when(() => repo.create(any())).thenAnswer((_) async => _template);
    when(() => repo.delete('t1')).thenAnswer((_) async {});
    final analytics = makeEnabledAnalytics(backend);
    await analytics.onConfigured();
    final bloc = TripTemplateBloc(repo, analytics: analytics);

    bloc.add(const TripTemplateCreated({'label': 'Lyon'}));
    await bloc.stream.firstWhere((s) => s.status == TripTemplateStatus.success);
    bloc.add(const TripTemplateDeleted('t1'));
    await bloc.stream.firstWhere((s) => s.templates.isEmpty);
    await settle();

    final captured = verify(
      () => backend.capture(AnalyticsEvents.tripTemplateSaved, captureAny()),
    ).captured;
    expect(captured, [
      {'action': 'created'},
      {'action': 'deleted'},
    ]);
  });

  test('création de modèle en échec : aucun événement', () async {
    final repo = _MockTemplateRepo();
    when(() => repo.create(any())).thenThrow(const ServerException());
    final analytics = makeEnabledAnalytics(backend);
    await analytics.onConfigured();
    final bloc = TripTemplateBloc(repo, analytics: analytics);

    bloc.add(const TripTemplateCreated({'label': 'Lyon'}));
    await bloc.stream.firstWhere((s) => s.status == TripTemplateStatus.error);
    await settle();

    verifyNever(
      () => backend.capture(AnalyticsEvents.tripTemplateSaved, any()),
    );
  });

  test('récurrence supprimée : trip_recurrence_saved', () async {
    final repo = _MockRecurrenceRepo();
    when(() => repo.delete('r1')).thenAnswer((_) async {});
    final analytics = makeEnabledAnalytics(backend);
    await analytics.onConfigured();
    final bloc = TripRecurrenceBloc(repo, analytics: analytics);

    bloc.add(const TripRecurrenceDeleted('r1'));
    await bloc.stream.firstWhere(
      (s) => s.status == TripRecurrenceStatus.success,
    );
    await settle();

    verify(
      () => backend.capture(AnalyticsEvents.tripRecurrenceSaved, {
        'action': 'deleted',
      }),
    ).called(1);
  });

  test('sans AnalyticsService : les blocs fonctionnent', () async {
    final repo = _MockTemplateRepo();
    when(() => repo.delete('t1')).thenAnswer((_) async {});
    final bloc = TripTemplateBloc(repo);

    bloc.add(const TripTemplateDeleted('t1'));
    await expectLater(
      bloc.stream,
      emits(
        isA<TripTemplateState>().having(
          (s) => s.status,
          'status',
          TripTemplateStatus.success,
        ),
      ),
    );
  });
}
