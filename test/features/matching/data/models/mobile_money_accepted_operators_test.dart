import 'package:dony/features/matching/data/models/mobile_money_accepted_operators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MobileMoneyAcceptedOperators', () {
    test('acceptedOperators_fromJson', () {
      final result = MobileMoneyAcceptedOperators.fromJson(const {
        'currency': 'XOF',
        'travelerFirstName': 'Awa',
        'providers': ['ORANGE_CIV', 'MTN_MOMO_CIV'],
      });

      expect(result.currency, 'XOF');
      expect(result.travelerFirstName, 'Awa');
      expect(result.providers, {'ORANGE_CIV', 'MTN_MOMO_CIV'});
    });

    test('providers absent : ensemble vide', () {
      final result = MobileMoneyAcceptedOperators.fromJson(const {
        'currency': 'XOF',
      });

      expect(result.providers, isEmpty);
      expect(result.travelerFirstName, isNull);
    });

    test('égalité par valeur', () {
      final a = MobileMoneyAcceptedOperators.fromJson(const {
        'currency': 'XOF',
        'travelerFirstName': 'Awa',
        'providers': ['ORANGE_CIV'],
      });
      final b = MobileMoneyAcceptedOperators.fromJson(const {
        'currency': 'XOF',
        'travelerFirstName': 'Awa',
        'providers': ['ORANGE_CIV'],
      });
      expect(a, b);
    });
  });
}
