import 'package:flutter_test/flutter_test.dart';
import 'package:dony/features/matching/data/models/address_suggestion.dart';

void main() {
  group('AddressSuggestion', () {
    test('fromJson parses all fields', () {
      final json = {
        'placeId': 'ChIJi...',
        'mainText': '12 rue Victor Hugo',
        'secondaryText': 'Lyon, France',
      };

      final suggestion = AddressSuggestion.fromJson(json);

      expect(suggestion.placeId, 'ChIJi...');
      expect(suggestion.mainText, '12 rue Victor Hugo');
      expect(suggestion.secondaryText, 'Lyon, France');
    });

    test('fullLabel concatenates mainText and secondaryText', () {
      const suggestion = AddressSuggestion(
        placeId: 'id1',
        mainText: 'Aéroport CDG',
        secondaryText: 'Roissy-en-France, France',
      );

      expect(suggestion.fullLabel, 'Aéroport CDG, Roissy-en-France, France');
    });

    test('equality is based on placeId, mainText, secondaryText', () {
      const a = AddressSuggestion(placeId: 'id1', mainText: 'Paris', secondaryText: 'France');
      const b = AddressSuggestion(placeId: 'id1', mainText: 'Paris', secondaryText: 'France');
      const c = AddressSuggestion(placeId: 'id2', mainText: 'Paris', secondaryText: 'France');

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });
  });
}
