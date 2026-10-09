import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/matching/bloc/trip_group_cubit.dart';
import 'package:dony/features/matching/bloc/trip_legs_cubit.dart';
import 'package:dony/features/matching/data/models/trip_legs_info.dart';
import 'package:dony/features/matching/data/repositories/announcement_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/mock_analytics_backend.dart';
import 'trip_fixtures.dart';

class _MockRepo extends Mock implements AnnouncementRepository {}

void main() {
  group('TripLegsCubit', () {
    TripLegsCubit build() {
      final analytics = makeDisabledAnalytics(MockAnalyticsBackend());
      analytics.onConfigured();
      return TripLegsCubit(analytics);
    }

    blocTest<TripLegsCubit, TripLegsState>(
      'ajoute, remplace puis retire une étape et les suivantes',
      build: build,
      act: (c) {
        c
          ..add(doualaLeg())
          ..add(doualaLeg(price: 7))
          ..replace(0, doualaLeg(price: 9))
          ..removeFrom(1);
      },
      expect: () => [
        TripLegsState(legs: [doualaLeg()]),
        TripLegsState(legs: [doualaLeg(), doualaLeg(price: 7)]),
        TripLegsState(legs: [doualaLeg(price: 9), doualaLeg(price: 7)]),
        TripLegsState(legs: [doualaLeg(price: 9)]),
      ],
    );

    blocTest<TripLegsCubit, TripLegsState>(
      'retirer la première étape ajoutée retire toutes les suivantes',
      build: build,
      seed: () => TripLegsState(legs: [doualaLeg(), doualaLeg(price: 7)]),
      act: (c) => c.removeFrom(0),
      expect: () => [const TripLegsState()],
    );

    blocTest<TripLegsCubit, TripLegsState>(
      'plafond : 5 étapes au total, premier trajet compris',
      build: build,
      act: (c) {
        for (var i = 0; i < 6; i++) {
          c.add(doualaLeg(price: i.toDouble() + 1));
        }
      },
      verify: (c) {
        expect(c.state.legs, hasLength(4));
        expect(c.state.canAdd, isFalse);
      },
    );

    blocTest<TripLegsCubit, TripLegsState>(
      'indices hors bornes ignorés',
      build: build,
      act: (c) => c
        ..replace(3, doualaLeg())
        ..removeFrom(-1),
      expect: () => <TripLegsState>[],
    );
  });

  group('TripGroupCubit', () {
    late _MockRepo repo;
    setUp(() => repo = _MockRepo());

    const info = TripLegsInfo(tripGroupId: 'g1', legCount: 2);

    blocTest<TripGroupCubit, TripGroupState>(
      'voyage : chargé',
      build: () {
        when(() => repo.getTripLegs('a')).thenAnswer(
          (_) async => TripLegsInfo.fromJson(const {
            'tripGroupId': 'g1',
            'legCount': 2,
            'legs': [
              {'id': 'a', 'legIndex': 1, 'departureDate': '2026-11-10'},
              {'id': 'b', 'legIndex': 2, 'departureDate': '2026-11-14'},
            ],
          }),
        );
        return TripGroupCubit(repo);
      },
      act: (c) => c.load('a'),
      verify: (c) {
        expect(c.state.status, TripGroupStatus.loaded);
        expect(c.state.info.legs, hasLength(2));
      },
    );

    blocTest<TripGroupCubit, TripGroupState>(
      'trajet isolé : masqué',
      build: () {
        when(() => repo.getTripLegs('a')).thenAnswer((_) async => info);
        return TripGroupCubit(repo);
      },
      act: (c) => c.load('a'),
      expect: () => [
        const TripGroupState(status: TripGroupStatus.loading),
        const TripGroupState(status: TripGroupStatus.hidden, info: info),
      ],
    );

    blocTest<TripGroupCubit, TripGroupState>(
      'échec (ancien backend) : masqué',
      build: () {
        when(() => repo.getTripLegs('a')).thenThrow(Exception('404'));
        return TripGroupCubit(repo);
      },
      act: (c) => c.load('a'),
      expect: () => [
        const TripGroupState(status: TripGroupStatus.loading),
        const TripGroupState(status: TripGroupStatus.hidden),
      ],
    );
    group('FLUTTER-H3 / H2 : cubit fermé pendant le chargement', () {
      Future<void> closeWhilePending({required bool fail}) async {
        final completer = Completer<TripLegsInfo>();
        when(() => repo.getTripLegs('a')).thenAnswer((_) => completer.future);
        final cubit = TripGroupCubit(repo);
        final emitted = <TripGroupState>[];
        final sub = cubit.stream.listen(emitted.add);

        final pending = cubit.load('a');
        await Future<void>.delayed(Duration.zero);
        expect(emitted, [
          const TripGroupState(status: TripGroupStatus.loading),
        ]);
        emitted.clear();

        await cubit.close();
        if (fail) {
          completer.completeError(Exception('réseau'));
        } else {
          completer.complete(info);
        }

        await expectLater(pending, completes);
        expect(emitted, isEmpty);
        await sub.cancel();
      }

      test('réponse reçue après close : aucune erreur, aucun état', () async {
        await closeWhilePending(fail: false);
      });

      test('échec reçu après close : aucune erreur, aucun état', () async {
        await closeWhilePending(fail: true);
      });

      test('load sur un cubit déjà fermé : ignoré', () async {
        final cubit = TripGroupCubit(repo);
        await cubit.close();
        await expectLater(cubit.load('a'), completes);
        verifyNever(() => repo.getTripLegs(any()));
      });
    });
  });
}
