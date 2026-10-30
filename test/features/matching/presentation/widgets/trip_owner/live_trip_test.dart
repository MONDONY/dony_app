// Outils communs aux bottom sheets de l'écran du trajet (`live_trip.dart`) :
// trajet tiré des six états qui le portent, filtré sur l'identifiant ;
// suivi d'un bloc qui ne reconstruit que pour une valeur utile, et repli
// sans bloc.
import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_event.dart';
import 'package:dony/features/matching/bloc/announcement_state.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/trip_reschedule_result.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/live_trip.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class _MockAnnouncementBloc
    extends MockBloc<AnnouncementEvent, AnnouncementState>
    implements AnnouncementBloc {}

AnnouncementModel _trip(String id, {String status = 'ACTIVE'}) =>
    AnnouncementModel(
      id: id,
      travelerId: 'trav-1',
      departureCity: 'Paris',
      arrivalCity: 'Dakar',
      departureDate: DateTime(2026, 11, 2),
      availableKg: 10,
      totalKg: 10,
      status: status,
      createdAt: DateTime(2026, 10),
      updatedAt: DateTime(2026, 10),
    );

const _reschedule = TripRescheduleResult(
  rescheduleId: 'r-1',
  rescheduleCount: 1,
  remainingReschedules: 1,
  parcelsAwaitingDecision: 0,
  requestsInformed: 0,
);

void main() {
  group('tripAnnouncementIn', () {
    final trip = _trip('trip-1');
    final carriers = <String, AnnouncementState>{
      'DetailLoaded': AnnouncementDetailLoaded(trip),
      'Updated': AnnouncementUpdated(trip),
      'Published': AnnouncementPublished(trip),
      'TripArrived': AnnouncementTripArrived(trip),
      'ArrivalInstructionsUpdated': AnnouncementArrivalInstructionsUpdated(
        trip,
      ),
      'Rescheduled': AnnouncementRescheduled(trip, _reschedule),
    };

    for (final MapEntry(key: name, value: state) in carriers.entries) {
      test('$name : le trajet', () {
        expect(tripAnnouncementIn(state, 'trip-1'), same(trip));
      });

      test('$name d\'un autre trajet : rien', () {
        expect(tripAnnouncementIn(state, 'other'), isNull);
      });
    }

    test('états sans trajet suivi : rien', () {
      for (final state in <AnnouncementState>[
        AnnouncementLoading(),
        AnnouncementDeleted(),
        AnnouncementError(const NetworkException('offline')),
        // Un trajet créé n'est pas relu par l'écran du trajet.
        AnnouncementCreated(trip),
      ]) {
        expect(tripAnnouncementIn(state, 'trip-1'), isNull, reason: '$state');
      }
    });
  });

  group('followBloc', () {
    testWidgets('bloc absent : valeur nulle, sans fournisseur', (tester) async {
      final seen = <String?>[];
      await tester.pumpWidget(
        followBloc<AnnouncementBloc, AnnouncementState, String>(
          present: false,
          select: (s) => tripAnnouncementIn(s, 'trip-1')?.status,
          builder: (context, value) {
            seen.add(value);
            return const SizedBox.shrink();
          },
        ),
      );

      expect(seen, [null]);
      expect(tester.takeException(), isNull);
    });

    testWidgets('ne reconstruit que pour une valeur utile, garde la dernière', (
      tester,
    ) async {
      final bloc = _MockAnnouncementBloc();
      final states = StreamController<AnnouncementState>.broadcast();
      addTearDown(states.close);
      whenListen(
        bloc,
        states.stream,
        initialState: AnnouncementDetailLoaded(_trip('trip-1')),
      );
      final seen = <String?>[];
      await tester.pumpWidget(
        BlocProvider<AnnouncementBloc>.value(
          value: bloc,
          child: followBloc<AnnouncementBloc, AnnouncementState, String>(
            present: true,
            select: (s) => tripAnnouncementIn(s, 'trip-1')?.status,
            builder: (context, value) {
              seen.add(value);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(seen, ['ACTIVE']);

      states.add(AnnouncementLoading());
      await tester.pumpAndSettle();
      states.add(AnnouncementUpdated(_trip('other', status: 'FULL')));
      await tester.pumpAndSettle();
      expect(seen, ['ACTIVE'], reason: 'chargement et autre trajet ignorés');

      states.add(AnnouncementUpdated(_trip('trip-1', status: 'FULL')));
      await tester.pumpAndSettle();
      expect(seen, ['ACTIVE', 'FULL']);
    });

    testWidgets('état initial sans valeur : nulle jusqu\'à la première', (
      tester,
    ) async {
      final bloc = _MockAnnouncementBloc();
      final states = StreamController<AnnouncementState>.broadcast();
      addTearDown(states.close);
      whenListen(bloc, states.stream, initialState: AnnouncementLoading());
      final seen = <String?>[];
      await tester.pumpWidget(
        BlocProvider<AnnouncementBloc>.value(
          value: bloc,
          child: followBloc<AnnouncementBloc, AnnouncementState, String>(
            present: true,
            select: (s) => tripAnnouncementIn(s, 'trip-1')?.status,
            builder: (context, value) {
              seen.add(value);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(seen, [null]);

      states.add(AnnouncementPublished(_trip('trip-1')));
      await tester.pumpAndSettle();
      expect(seen, [null, 'ACTIVE']);
    });
  });
}
