// Constructeurs appelés à l'exécution : un appel `const` n'est jamais exécuté
// et deux instances `const` identiques court-circuitent la comparaison.
// ignore_for_file: prefer_const_constructors

import 'dart:async';

import 'package:dony/features/matching/bloc/traveler_bids_event.dart';
import 'package:dony/features/matching/bloc/traveler_bids_state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/value_equality.dart';

void main() {
  group('TravelerBidsEvent — égalité de valeur', () {
    test('TravelerBidsRequested compare force, complétion et filtre auto', () {
      final done = Completer<Object?>();
      expectValueEquality(
        () => TravelerBidsRequested(force: true, done: done),
        [
          TravelerBidsRequested(force: true),
          TravelerBidsRequested(done: done),
          TravelerBidsRequested(
            force: true,
            done: done,
            autoSelectFilter: true,
          ),
        ],
      );
    });

    test('page suivante : sans champ', () {
      expectValueEquality(() => TravelerBidsNextPageRequested(), [
        TravelerBidsRequested(),
      ]);
      expect(TravelerBidsNextPageRequested().props, isEmpty);
    });

    test('changement de filtre', () {
      expectValueEquality(
        () => TravelerBidsFilterChanged(TravelerBidFilter.acceptees),
        [TravelerBidsFilterChanged(TravelerBidFilter.terminees)],
      );
    });
  });
}
