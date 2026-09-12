import 'package:dony/features/payments/data/models/mobile_money_provider_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MobileMoneyProviderOption', () {
    test('parse le JSON, label replié sur le code, detected faux par défaut', () {
      final full = MobileMoneyProviderOption.fromJson(const {
        'code': 'ORANGE_CIV',
        'label': 'Orange Money',
        'detected': true,
      });
      expect(full.code, 'ORANGE_CIV');
      expect(full.label, 'Orange Money');
      expect(full.detected, isTrue);
      final bare = MobileMoneyProviderOption.fromJson(const {'code': 'WAVE_CIV'});
      expect(bare.label, 'WAVE_CIV');
      expect(bare.detected, isFalse);
    });

    test('brand est le préfixe avant le premier underscore', () {
      expect(
        const MobileMoneyProviderOption(code: 'ORANGE_CIV', label: 'x').brand,
        'ORANGE',
      );
      expect(
        const MobileMoneyProviderOption(code: 'MTN_MOMO_CMR', label: 'x').brand,
        'MTN',
      );
      expect(const MobileMoneyProviderOption(code: 'wave', label: 'x').brand, 'WAVE');
    });
  });

  group('MobileMoneyProviderCatalog', () {
    final json = {
      'country': 'CI',
      'currency': 'XOF',
      'msisdnMasked': '+225 •••• 36',
      'detected': 'ORANGE_CIV',
      'providers': [
        {'code': 'ORANGE_CIV', 'label': 'Orange Money', 'detected': true},
        {'code': 'WAVE_CIV', 'label': 'Wave', 'detected': false},
        {'code': 'MTN_CIV', 'label': 'MTN MoMo'},
      ],
      'travelerAccepts': ['Orange Money', 'Wave'],
      'travelerFirstName': 'Aminata',
    };

    test('parse le catalogue complet', () {
      final c = MobileMoneyProviderCatalog.fromJson(json);
      expect(c.country, 'CI');
      expect(c.currency, 'XOF');
      expect(c.msisdnMasked, '+225 •••• 36');
      expect(c.detected, 'ORANGE_CIV');
      expect(c.providers.map((p) => p.code), ['ORANGE_CIV', 'WAVE_CIV', 'MTN_CIV']);
      expect(c.travelerAccepts, ['Orange Money', 'Wave']);
      expect(c.travelerFirstName, 'Aminata');
      expect(c.isEmpty, isFalse);
      expect(c.detectedOption?.code, 'ORANGE_CIV');
    });

    test('tolère les champs absents (réponse voyageur, liste vide)', () {
      final c = MobileMoneyProviderCatalog.fromJson(const {'country': 'SN', 'providers': []});
      expect(c.isEmpty, isTrue);
      expect(c.detected, isNull);
      expect(c.detectedOption, isNull);
      expect(c.travelerAccepts, isEmpty);
      expect(c.travelerFirstName, isNull);
      expect(c.currency, isNull);
    });

    test('ordered rend les codes sélectionnés dans l\'ordre du catalogue', () {
      final c = MobileMoneyProviderCatalog.fromJson(json);
      expect(c.ordered({'MTN_CIV', 'ORANGE_CIV'}), ['ORANGE_CIV', 'MTN_CIV']);
      expect(c.ordered({}), isEmpty);
    });

    test('ordered ignore les codes inconnus et conserve l\'ordre du catalogue', () {
      final c = MobileMoneyProviderCatalog.fromJson(json);
      expect(c.ordered({'CODE_INEXISTANT', 'ORANGE_CIV'}), ['ORANGE_CIV']);
    });

    test('detectedOption ignore le detected de premier niveau : seul le detected de chaque option compte', () {
      final codeAbsentDesProviders = MobileMoneyProviderCatalog.fromJson(const {
        'detected': 'ORANGE_CIV',
        'providers': [
          {'code': 'WAVE_CIV', 'label': 'Wave'},
        ],
      });
      expect(codeAbsentDesProviders.detectedOption, isNull);

      final codePresentSansFlag = MobileMoneyProviderCatalog.fromJson(const {
        'detected': 'ORANGE_CIV',
        'providers': [
          {'code': 'ORANGE_CIV', 'label': 'Orange Money'},
        ],
      });
      expect(codePresentSansFlag.detectedOption, isNull);
    });
  });
}
