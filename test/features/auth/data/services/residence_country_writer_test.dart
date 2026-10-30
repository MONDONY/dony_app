import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/features/auth/data/services/residence_country_writer.dart';
import 'package:dony/features/settings/data/models/user_business_prefs_dto.dart';
import 'package:dony/features/settings/data/repositories/business_prefs_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mocktail/mocktail.dart';

class _MockBusinessPrefsRepository extends Mock
    implements BusinessPrefsRepository {}

class _MockBox extends Mock implements Box<dynamic> {}

class _FakeUserBusinessPrefsDto extends Fake implements UserBusinessPrefsDto {}

const _current = UserBusinessPrefsDto(
  weightUnit: 'kg',
  currencyCode: 'EUR',
  defaultPackageWeightKg: 23,
  minBidPriceEur: 0,
);

const _saved = UserBusinessPrefsDto(
  weightUnit: 'kg',
  currencyCode: 'XOF',
  defaultPackageWeightKg: 23,
  minBidPriceEur: 0,
  country: 'SN',
);

void main() {
  late _MockBusinessPrefsRepository repository;
  late _MockBox prefs;

  setUpAll(() => registerFallbackValue(_FakeUserBusinessPrefsDto()));

  setUp(() {
    repository = _MockBusinessPrefsRepository();
    prefs = _MockBox();
    when(() => repository.fetchPrefs()).thenAnswer((_) async => _current);
    when(() => repository.updatePrefs(any())).thenAnswer((_) async => _saved);
    when(() => prefs.put(any(), any())).thenAnswer((_) async {});
  });

  test(
    'écrit le pays au serveur, puis Hive avec la devise du serveur',
    () async {
      await writeResidenceCountry(repository, prefs, 'SN');

      verifyInOrder([
        () => repository.fetchPrefs(),
        () => repository.updatePrefs(
          any(
            that: isA<UserBusinessPrefsDto>()
                .having((dto) => dto.country, 'country', 'SN')
                .having((dto) => dto.weightUnit, 'weightUnit', 'kg'),
          ),
        ),
        () => prefs.put(HiveService.kCountryCode, 'SN'),
        () => prefs.put(HiveService.kCurrencyCode, 'XOF'),
        () => prefs.put(HiveService.kTravelerCountryUnsupported, false),
      ]);
    },
  );

  test('un refus du serveur ne touche pas Hive et remonte l\'erreur', () async {
    when(() => repository.updatePrefs(any())).thenThrow(Exception('422'));

    await expectLater(
      writeResidenceCountry(repository, prefs, 'SN'),
      throwsException,
    );
    verifyNever(() => prefs.put(any(), any()));
  });
}
