// Tests pour DonyIcons — vérifie que les constantes statiques sont accessibles
// et que les valeurs sont des IconData valides.
// Note : la ligne 7 (DonyIcons._()) est le constructeur privé ; ce n'est pas
// testable via des tests unitaires Dart (intentionnel — classe non instantiable).
import 'package:dony/core/design/dony_icons.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DonyIcons — constantes statiques', () {
    test('departureCity est un IconData valide', () {
      expect(DonyIcons.departureCity, isA<IconData>());
    });

    test('arrivalCity est un IconData valide', () {
      expect(DonyIcons.arrivalCity, isA<IconData>());
    });

    test('date est un IconData valide', () {
      expect(DonyIcons.date, isA<IconData>());
    });

    test('time est un IconData valide', () {
      expect(DonyIcons.time, isA<IconData>());
    });

    test('mapPin est un IconData valide', () {
      expect(DonyIcons.mapPin, isA<IconData>());
    });

    test('suitcase est un IconData valide', () {
      expect(DonyIcons.suitcase, isA<IconData>());
    });

    test('card est un IconData valide', () {
      expect(DonyIcons.card, isA<IconData>());
    });

    test('cash est un IconData valide', () {
      expect(DonyIcons.cash, isA<IconData>());
    });

    test('publish est un IconData valide', () {
      expect(DonyIcons.publish, isA<IconData>());
    });

    test('close est un IconData valide', () {
      expect(DonyIcons.close, isA<IconData>());
    });

    test('back est un IconData valide', () {
      expect(DonyIcons.back, isA<IconData>());
    });

    test('arrowRight est un IconData valide', () {
      expect(DonyIcons.arrowRight, isA<IconData>());
    });

    test('transportPlane est un IconData valide', () {
      expect(DonyIcons.transportPlane, isA<IconData>());
    });

    test('confirmed est un IconData valide', () {
      expect(DonyIcons.confirmed, isA<IconData>());
    });
  });
}
