import 'package:dony/features/settings/data/models/user_business_prefs_dto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('countryChangeResetsPayoutSetup (yadony-back #530)', () {
    test('lu depuis la réponse du serveur', () {
      final dto = UserBusinessPrefsDto.fromJson(const {
        'country': 'FR',
        'countryLocked': false,
        'countryChangeResetsPayoutSetup': true,
      });

      expect(dto.countryChangeResetsPayoutSetup, isTrue);
      expect(dto.countryLocked, isFalse);
    });

    test('absent (backend antérieur) : false, comportement historique', () {
      final dto = UserBusinessPrefsDto.fromJson(const {'country': 'FR'});

      expect(dto.countryChangeResetsPayoutSetup, isFalse);
    });

    test('lecture seule : jamais renvoyé au PUT', () {
      const dto = UserBusinessPrefsDto(
        weightUnit: 'kg',
        currencyCode: 'EUR',
        defaultPackageWeightKg: 23,
        minBidPriceEur: 0,
        countryChangeResetsPayoutSetup: true,
      );

      expect(
        dto.toJson().containsKey('countryChangeResetsPayoutSetup'),
        isFalse,
      );
    });

    test('copyWith le garde, ou le remplace', () {
      const dto = UserBusinessPrefsDto(
        weightUnit: 'kg',
        currencyCode: 'EUR',
        defaultPackageWeightKg: 23,
        minBidPriceEur: 0,
        countryChangeResetsPayoutSetup: true,
      );

      expect(
        dto.copyWith(country: 'SN').countryChangeResetsPayoutSetup,
        isTrue,
      );
      expect(
        dto
            .copyWith(countryChangeResetsPayoutSetup: false)
            .countryChangeResetsPayoutSetup,
        isFalse,
      );
    });
  });
}
