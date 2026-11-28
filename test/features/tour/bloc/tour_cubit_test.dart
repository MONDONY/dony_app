import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/tour/bloc/tour_cubit.dart';
import 'package:dony/features/tour/data/tour_progress_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mocktail/mocktail.dart';

class _MockBox extends Mock implements Box<dynamic> {}

class _MockAnalytics extends Mock implements AnalyticsService {}

void main() {
  late _MockBox box;
  late _MockAnalytics analytics;
  late TourCubit cubit;
  final stored = <String, dynamic>{};

  setUp(() {
    stored.clear();
    box = _MockBox();
    when(
      () => box.get(any()),
    ).thenAnswer((inv) => stored[inv.positionalArguments.first as String]);
    when(() => box.put(any(), any())).thenAnswer((inv) async {
      stored[inv.positionalArguments[0] as String] = inv.positionalArguments[1];
    });
    analytics = _MockAnalytics();
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
    cubit = TourCubit(TourProgressStore(box), analytics);
  });

  tearDown(() => cubit.close());

  test('avant toute lecture : ni bulle ni tour fini', () {
    expect(cubit.state.step, isNull);
    expect(cubit.state.finished, isFalse);
  });

  test('sans compte, le tour n\'a pas lieu et n\'est pas fini', () {
    cubit.sync(null);
    expect(cubit.state.step, isNull);
    expect(cubit.state.finished, isFalse);
  });

  test('un compte neuf commence par le bouton +', () {
    cubit.sync('uid-1');
    expect(cubit.state.step, TourStep.plus);
    expect(cubit.state.finished, isFalse);
  });

  test('l\'avancée mémorisée est reprise', () {
    stored['${TourProgressStore.keyPrefix}uid-1'] = 2;
    cubit.sync('uid-1');
    expect(cubit.state.step, TourStep.modeParcels);
  });

  test('un tour terminé pour un compte l\'est pour ce compte seulement', () {
    stored['${TourProgressStore.keyPrefix}uid-1'] = TourStep.values.length;
    cubit.sync('uid-1');
    expect(cubit.state.finished, isTrue);
    cubit.sync('uid-2');
    expect(cubit.state.step, TourStep.plus);
  });

  test('la bulle n\'est mesurée qu\'une fois par étape', () {
    cubit.sync('uid-1');
    cubit
      ..shown()
      ..shown();
    verify(
      () => analytics.logEvent(
        AnalyticsEvents.tourStepShown,
        properties: {'step': 'plus', 'position': 1},
      ),
    ).called(1);
  });

  test('« Suivant » avance, mémorise et mesure', () async {
    cubit.sync('uid-1');
    await cubit.next();
    expect(cubit.state.step, TourStep.modeTrips);
    expect(stored['${TourProgressStore.keyPrefix}uid-1'], 1);
    verify(
      () => analytics.logEvent(
        AnalyticsEvents.tourStepNext,
        properties: {'step': 'plus'},
      ),
    ).called(1);
  });

  test('la dernière bulle termine le tour une fois pour toutes', () async {
    stored['${TourProgressStore.keyPrefix}uid-1'] = TourStep.values.length - 1;
    cubit.sync('uid-1');
    await cubit.next();
    expect(cubit.state.finished, isTrue);
    expect(
      stored['${TourProgressStore.keyPrefix}uid-1'],
      TourStep.values.length,
    );
    verify(() => analytics.logEvent(AnalyticsEvents.tourCompleted)).called(1);
  });

  test('« Passer le tour » écarte tout et le mesure', () async {
    cubit.sync('uid-1');
    await cubit.next();
    await cubit.skip();
    expect(cubit.state.finished, isTrue);
    expect(
      stored['${TourProgressStore.keyPrefix}uid-1'],
      TourStep.values.length,
    );
    verify(
      () => analytics.logEvent(
        AnalyticsEvents.tourSkipped,
        properties: {'step': 'modeTrips', 'position': 2},
      ),
    ).called(1);
    verifyNever(() => analytics.logEvent(AnalyticsEvents.tourCompleted));
  });

  test('suivant et passer sans bulle ne font rien', () async {
    cubit.sync(null);
    await cubit.next();
    await cubit.skip();
    verifyNever(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    );
  });
}
