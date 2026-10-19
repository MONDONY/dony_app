import 'package:dony/features/payments/data/models/mobile_money_countries.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, dynamic> backExample() => {
    'available': [
      {
        'country': 'CI',
        'currency': 'XOF',
        'operators': [
          {
            'code': 'ORANGE_CIV',
            'label': 'Orange Money',
            'brand': 'ORANGE',
            'validationHint': 'SMS_LINK',
            'minAmount': 100,
            'maxAmount': 1500000,
          },
        ],
      },
    ],
    'upcoming': ['ML'],
  };

  group('MobileMoneyValidationHint.fromWire', () {
    test('SMS_LINK, PIN_PROMPT et GENERIC', () {
      expect(
        MobileMoneyValidationHint.fromWire('SMS_LINK'),
        MobileMoneyValidationHint.smsLink,
      );
      expect(
        MobileMoneyValidationHint.fromWire('PIN_PROMPT'),
        MobileMoneyValidationHint.pinPrompt,
      );
      expect(
        MobileMoneyValidationHint.fromWire('GENERIC'),
        MobileMoneyValidationHint.generic,
      );
    });

    test('valeur inconnue ou nulle : generic', () {
      expect(
        MobileMoneyValidationHint.fromWire('NOUVEAU'),
        MobileMoneyValidationHint.generic,
      );
      expect(
        MobileMoneyValidationHint.fromWire(null),
        MobileMoneyValidationHint.generic,
      );
    });
  });

  group('MobileMoneyCountries.fromJson', () {
    test('parse l\'exemple du back', () {
      final countries = MobileMoneyCountries.fromJson(backExample());

      expect(countries.available, hasLength(1));
      final ci = countries.available.single;
      expect(ci.country, 'CI');
      expect(ci.currency, 'XOF');
      final orange = ci.operators.single;
      expect(orange.code, 'ORANGE_CIV');
      expect(orange.label, 'Orange Money');
      expect(orange.brand, 'ORANGE');
      expect(orange.validationHint, MobileMoneyValidationHint.smsLink);
      expect(orange.minAmount, 100.0);
      expect(orange.maxAmount, 1500000.0);
      expect(countries.upcoming, ['ML']);
    });

    test('min et max nuls ou absents restent null', () {
      final countries = MobileMoneyCountries.fromJson(const {
        'available': [
          {
            'country': 'SN',
            'currency': 'XOF',
            'operators': [
              {
                'code': 'WAVE_SEN',
                'label': 'Wave',
                'brand': 'WAVE',
                'validationHint': 'PIN_PROMPT',
                'minAmount': null,
              },
            ],
          },
        ],
      });

      final wave = countries.available.single.operators.single;
      expect(wave.minAmount, isNull);
      expect(wave.maxAmount, isNull);
      expect(wave.validationHint, MobileMoneyValidationHint.pinPrompt);
    });

    test('validationHint inconnu ou absent : generic', () {
      final json = backExample();
      final operators =
          ((json['available'] as List).first as Map)['operators'] as List;
      (operators.first as Map<String, dynamic>)['validationHint'] = 'AUTRE';
      operators.add({'code': 'MTN_CIV', 'label': 'MTN MoMo', 'brand': 'MTN'});

      final parsed = MobileMoneyCountries.fromJson(json);

      final ops = parsed.available.single.operators;
      expect(ops[0].validationHint, MobileMoneyValidationHint.generic);
      expect(ops[1].validationHint, MobileMoneyValidationHint.generic);
    });

    test('listes absentes : vides', () {
      final countries = MobileMoneyCountries.fromJson(const {});

      expect(countries.available, isEmpty);
      expect(countries.upcoming, isEmpty);
    });

    test('pays sans opérateurs : liste vide', () {
      final countries = MobileMoneyCountries.fromJson(const {
        'available': [
          {'country': 'CI', 'currency': 'XOF'},
        ],
      });

      expect(countries.available.single.operators, isEmpty);
    });
  });

  group('byCode et isUpcoming', () {
    final countries = MobileMoneyCountries.fromJson(backExample());

    test('byCode trouve le pays, insensible à la casse', () {
      expect(countries.byCode('CI')?.currency, 'XOF');
      expect(countries.byCode('ci')?.country, 'CI');
    });

    test('byCode renvoie null pour un pays absent', () {
      expect(countries.byCode('SN'), isNull);
      expect(countries.byCode('ML'), isNull);
    });

    test('isUpcoming', () {
      expect(countries.isUpcoming('ML'), isTrue);
      expect(countries.isUpcoming('ml'), isTrue);
      expect(countries.isUpcoming('CI'), isFalse);
    });
  });

  test('égalité par valeur (Equatable)', () {
    expect(
      MobileMoneyCountries.fromJson(backExample()),
      MobileMoneyCountries.fromJson(backExample()),
    );
  });
}
