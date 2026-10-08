import 'package:dony/features/matching/presentation/utils/trip_group_list.dart';
import 'package:flutter_test/flutter_test.dart';

import 'trip_fixtures.dart';

void main() {
  final solo1 = legModel(id: 's1', from: 'Lyon', to: 'Dakar');
  final leg2 = legModel(
    id: 'b',
    from: 'Abidjan',
    to: 'Douala',
    group: 'g',
    index: 2,
    count: 2,
  );
  final solo2 = legModel(id: 's2', from: 'Paris', to: 'Bamako');
  final leg1 = legModel(
    id: 'a',
    from: 'Paris',
    to: 'Abidjan',
    group: 'g',
    index: 1,
    count: 2,
  );

  test('ramène les étapes d\'un voyage ensemble, dans l\'ordre du voyage', () {
    final out = groupTripLegs([solo1, leg2, solo2, leg1]);
    expect(out.map((a) => a.id), ['s1', 'a', 'b', 's2']);
  });

  test('liste sans voyage inchangée', () {
    expect(groupTripLegs([solo1, solo2]).map((a) => a.id), ['s1', 's2']);
  });

  test('début et suite de bloc', () {
    final out = groupTripLegs([solo1, leg2, solo2, leg1]);
    expect(startsTripGroup(out, 0), isFalse);
    expect(startsTripGroup(out, 1), isTrue);
    expect(startsTripGroup(out, 2), isFalse);
    expect(continuesTripGroup(out, 1), isTrue);
    expect(continuesTripGroup(out, 2), isFalse);
    expect(continuesTripGroup(out, 3), isFalse);
    expect(continuesTripGroup(out, 0), isFalse);
  });

  test('itinéraire du voyage', () {
    expect(tripGroupRoute([leg2, leg1], 'g'), 'Paris → Abidjan → Douala');
    expect(tripGroupRoute([leg1], 'inconnu'), '');
  });

  test('étape intermédiaire absente : la rupture reste lisible', () {
    final leg3 = legModel(
      id: 'c',
      from: 'Lomé',
      to: 'Paris',
      group: 'g',
      index: 3,
    );
    expect(tripGroupRoute([leg1, leg3], 'g'), 'Paris → Abidjan → Lomé → Paris');
  });
}
