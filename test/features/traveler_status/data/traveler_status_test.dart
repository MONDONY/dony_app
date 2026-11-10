import 'package:dony/features/traveler_status/data/traveler_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TravelerStatus.parse', () {
    test('lit les deux valeurs du back', () {
      expect(TravelerStatus.parse('INDIVIDUAL'), TravelerStatus.individual);
      expect(TravelerStatus.parse('PROFESSIONAL'), TravelerStatus.professional);
    });

    test('null (non déclaré ou ancien back) donne null', () {
      expect(TravelerStatus.parse(null), isNull);
    });

    test('valeur inconnue donne null, jamais d\'exception', () {
      expect(TravelerStatus.parse('ROBOT'), isNull);
      expect(TravelerStatus.parse(''), isNull);
      expect(TravelerStatus.parse('individual'), isNull);
    });

    test('wire reprend la valeur envoyée au back', () {
      expect(TravelerStatus.individual.wire, 'INDIVIDUAL');
      expect(TravelerStatus.professional.wire, 'PROFESSIONAL');
    });
  });
}
