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
  late DateTime clock;
  final stored = <String, dynamic>{};

  String seenKey(String uid) => '${TourProgressStore.seenPrefix}$uid';
  int bit(TourStep s) => 1 << s.index;
  final sequentialMask = TourStep.sequential.map(bit).reduce((a, b) => a | b);
  final allMask = TourStep.values.map(bit).reduce((a, b) => a | b);

  setUp(() {
    stored.clear();
    clock = DateTime(2026, 11, 28, 10);
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
    cubit = TourCubit(TourProgressStore(box), analytics, now: () => clock);
  });

  tearDown(() => cubit.close());

  /// Un compte qui a fini le tour il y a [daysAgo] jours.
  void tourDone({int daysAgo = 0, int extraSeen = 0}) {
    stored[seenKey('uid-1')] = sequentialMask | extraSeen;
    stored['${TourProgressStore.doneAtPrefix}uid-1'] = clock
        .subtract(Duration(days: daysAgo))
        .millisecondsSinceEpoch;
  }

  test('avant toute lecture : ni bulle ni assistant', () {
    expect(cubit.state.step, isNull);
    expect(cubit.state.finished, isFalse);
  });

  test('sans compte, rien ne s\'affiche', () {
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
    stored[seenKey('uid-1')] = bit(TourStep.plus) | bit(TourStep.modeTrips);
    cubit.sync('uid-1');
    expect(cubit.state.step, TourStep.modeParcels);
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
    expect(stored[seenKey('uid-1')], bit(TourStep.plus));
    verify(
      () => analytics.logEvent(
        AnalyticsEvents.tourStepNext,
        properties: {'step': 'plus'},
      ),
    ).called(1);
  });

  test('la dernière bulle du tour le termine et date la fin', () async {
    stored[seenKey('uid-1')] = sequentialMask & ~bit(TourStep.activities);
    cubit.sync('uid-1');
    await cubit.next();
    expect(cubit.state.step, isNull);
    expect(stored[seenKey('uid-1')], sequentialMask);
    expect(
      stored['${TourProgressStore.doneAtPrefix}uid-1'],
      clock.millisecondsSinceEpoch,
    );
    verify(() => analytics.logEvent(AnalyticsEvents.tourCompleted)).called(1);
  });

  test('le tour fini ne rend pas l\'assistant tout de suite', () async {
    stored[seenKey('uid-1')] = sequentialMask & ~bit(TourStep.activities);
    cubit.sync('uid-1');
    await cubit.next();
    expect(cubit.state.finished, isFalse);
  });

  test('« Passer le tour » écarte les quatre bulles et le mesure', () async {
    cubit.sync('uid-1');
    await cubit.next();
    await cubit.skip();
    expect(cubit.state.step, isNull);
    expect(stored[seenKey('uid-1')], sequentialMask);
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

  group('bulles au moment utile', () {
    test('rien tant que le tour n\'est pas fini', () {
      cubit.sync('uid-1');
      cubit.trigger(TourStep.urgent);
      expect(cubit.state.step, TourStep.plus);
    });

    test('le premier filtre touché montre la bulle Urgent', () {
      tourDone();
      cubit.sync('uid-1');
      expect(cubit.state.step, isNull);
      cubit.trigger(TourStep.urgent);
      expect(cubit.state.step, TourStep.urgent);
    });

    test('le premier cœur montre la bulle des favoris', () {
      tourDone();
      cubit.sync('uid-1');
      cubit.trigger(TourStep.favorites);
      expect(cubit.state.step, TourStep.favorites);
    });

    test('une bulle déjà vue ne revient pas', () {
      tourDone(extraSeen: bit(TourStep.urgent));
      cubit.sync('uid-1');
      cubit.trigger(TourStep.urgent);
      expect(cubit.state.step, isNull);
    });

    test('un déclencheur sur une bulle du tour est ignoré', () {
      tourDone();
      cubit.sync('uid-1');
      cubit.trigger(TourStep.plus);
      expect(cubit.state.step, isNull);
    });

    test('« Compris » ferme la bulle et la mémorise', () async {
      tourDone();
      cubit.sync('uid-1');
      cubit
        ..trigger(TourStep.urgent)
        ..shown();
      await cubit.next();
      expect(cubit.state.step, isNull);
      expect(stored[seenKey('uid-1')], sequentialMask | bit(TourStep.urgent));
    });

    test('une seule bulle par jour, la suivante attend demain', () async {
      tourDone();
      cubit.sync('uid-1');
      cubit
        ..trigger(TourStep.urgent)
        ..trigger(TourStep.favorites)
        ..shown();
      expect(cubit.state.step, TourStep.urgent);
      await cubit.next();
      expect(cubit.state.step, isNull);

      clock = clock.add(const Duration(days: 1));
      cubit.sync('uid-2');
      stored[seenKey('uid-1')] = sequentialMask | bit(TourStep.urgent);
      stored['${TourProgressStore.lastContextualPrefix}uid-1'] = '2026-11-28';
      cubit.sync('uid-1');
      cubit.trigger(TourStep.favorites);
      expect(cubit.state.step, TourStep.favorites);
    });

    test('la bulle affichée reste jusqu\'à ce qu\'on la ferme', () {
      tourDone();
      cubit.sync('uid-1');
      cubit
        ..trigger(TourStep.urgent)
        ..shown()
        ..trigger(TourStep.favorites);
      expect(cubit.state.step, TourStep.urgent);
    });

    test('utiliser le bouton rend sa bulle inutile', () async {
      tourDone();
      cubit.sync('uid-1');
      await cubit.markSeen(TourStep.urgent);
      cubit.trigger(TourStep.urgent);
      expect(cubit.state.step, isNull);
    });

    test('« Passer » sur une de ces bulles ne touche pas au tour', () async {
      tourDone();
      cubit.sync('uid-1');
      cubit.trigger(TourStep.urgent);
      await cubit.skip();
      expect(cubit.state.step, isNull);
      verifyNever(
        () => analytics.logEvent(
          AnalyticsEvents.tourSkipped,
          properties: any(named: 'properties'),
        ),
      );
    });
  });

  group('bulle du support', () {
    test('pas avant trois jours', () {
      tourDone(daysAgo: 2);
      cubit.sync('uid-1');
      expect(cubit.state.step, isNull);
    });

    test('trois jours après la fin du tour, elle se montre', () {
      tourDone(daysAgo: 3);
      cubit.sync('uid-1');
      expect(cubit.state.step, TourStep.support);
    });
  });

  group('assistant', () {
    test('attend sept jours si des bulles ne se sont pas déclenchées', () {
      tourDone(daysAgo: 6);
      cubit.sync('uid-1');
      expect(cubit.state.finished, isFalse);
    });

    test('sept jours après le tour, il peut venir', () {
      tourDone(daysAgo: 7);
      cubit.sync('uid-1');
      expect(cubit.state.finished, isTrue);
    });

    test('toutes les bulles vues, il vient sans attendre', () {
      stored[seenKey('uid-1')] = allMask;
      cubit.sync('uid-1');
      expect(cubit.state.finished, isTrue);
    });

    test('un tour fini sans date en reçoit une', () {
      stored[seenKey('uid-1')] = sequentialMask;
      cubit.sync('uid-1');
      expect(
        stored['${TourProgressStore.doneAtPrefix}uid-1'],
        clock.millisecondsSinceEpoch,
      );
    });

    test('un autre compte repart de zéro', () {
      stored[seenKey('uid-1')] = allMask;
      cubit.sync('uid-1');
      expect(cubit.state.finished, isTrue);
      cubit.sync('uid-2');
      expect(cubit.state.step, TourStep.plus);
      expect(cubit.state.finished, isFalse);
    });
  });
}
